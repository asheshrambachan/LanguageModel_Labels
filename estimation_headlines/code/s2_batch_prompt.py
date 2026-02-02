import os
import pandas as pd
from openai import OpenAI
from constants import API_KEY, step1_path, step2_path
from constants import economic_questions, models, month_batches, years

def initialize_client(api_key):
    """Initializes and returns the OpenAI client using the provided API key."""
    return OpenAI(api_key=api_key)

def create_batch_input_file(client, file_path):
    """Uploads a batch input file to OpenAI's servers and returns the file ID."""
    with open(file_path, "rb") as file:
        batch_input_file = client.files.create(
            file=file,
            purpose="batch"
        )
    return batch_input_file.id

def create_batch(client, batch_input_file_id, description):
    """Creates a batch on OpenAI's servers using the input file ID and description."""
    return client.batches.create(
        input_file_id=batch_input_file_id,
        endpoint="/v1/chat/completions",
        completion_window="24h",
        metadata={"description": description}
    )

def main(question, model, month, year):
    """
    Main function to create a batch on OpenAI's servers. 
    Returns a list of tuples: (question, model, month, year, batch_id)
    """
    description = f"{model} {question} {month} {year}"
    print(f"Creating batch for {description}")
    model_path = os.path.join(step1_path, model, f'q{question}')

    client = initialize_client(API_KEY)

    results = []

    if month == "oct":
        # File paths for both halves of October data
        file_path1 = os.path.join(model_path, f'q{question}_{month}first{year}_prompts.jsonl')
        file_path2 = os.path.join(model_path, f'q{question}_{month}second{year}_prompts.jsonl')

        # Create batches for both files
        batch_input_file_id1 = create_batch_input_file(client, file_path1)
        batch1 = create_batch(client, batch_input_file_id1, description=f"{description} first").id

        batch_input_file_id2 = create_batch_input_file(client, file_path2)
        batch2 = create_batch(client, batch_input_file_id2, description=f"{description} second").id

        # Store results
        results.append((question, model, f'{month}first', year, batch1))
        results.append((question, model, f'{month}second', year, batch2))

    else:
        # Normal case for non-October months
        file_path = os.path.join(model_path, f'q{question}_{month}{year}_prompts.jsonl')
        batch_input_file_id = create_batch_input_file(client, file_path)
        batch = create_batch(client, batch_input_file_id, description=description).id
        results.append((question, model, month, year, batch))

    return results

if __name__ == "__main__":
    all_results = []
    for question in economic_questions:
        for model in models:
            for month in month_batches:
                for year in years:
                    # main returns a list of tuples
                    batch_results = main(question, model, month, year)
                    all_results.extend(batch_results)
                    print(f"Submitted batch for {question}, {model}, {month}, {year}")

    # Convert all_results to a DataFrame
    batch_data = pd.DataFrame(all_results, columns=["question", "model", "month", "year", "batch_id"])
    if not os.path.exists(step2_path):
        os.makedirs(step2_path)
    batch_data.to_csv(f"{step2_path}/batch_data.csv", index=False)
