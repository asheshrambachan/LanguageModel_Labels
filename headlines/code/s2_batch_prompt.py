from openai import OpenAI
import os
from constants import API_KEY, step1_path

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
    """Main function to create a batch on OpenAI's servers."""
    description = f"{model} {question} {month} {year}"
    model_path = os.path.join(step1_path, model, f'q{question}')
    
    # Initialize the client
    client = initialize_client(API_KEY)
    
    if month == "oct":
        # File paths for both halves of October data
        file_path1 = os.path.join(model_path, f'q{question}_{month}first{year}_prompts.jsonl')
        file_path2 = os.path.join(model_path, f'q{question}_{month}second{year}_prompts.jsonl')

        # Create batches for both files
        batch_input_file_id1 = create_batch_input_file(client, file_path1)
        batch1 = create_batch(client, batch_input_file_id1, description=f"{description} first")

        batch_input_file_id2 = create_batch_input_file(client, file_path2)
        batch2 = create_batch(client, batch_input_file_id2, description=f"{description} second")

        print(batch1)
        print(batch2)

    else:
        # Normal case for non-October months
        file_path = os.path.join(model_path, f'q{question}_{month}{year}_prompts.jsonl')

        # Create batch
        batch_input_file_id = create_batch_input_file(client, file_path)
        batch = create_batch(client, batch_input_file_id, description=description)

        print(batch)

if __name__ == "__main__":

    QUESTIONS = ["1"]
    MODELS = ["gpt-3.5-turbo", "gpt-4o", "gpt-4o-mini"]
    MONTHS = ["jan"]
    YEARS = ["19"]

    for question in QUESTIONS:
        for model in MODELS:
            for month in MONTHS:
                for year in YEARS:
                    main(question, model, month, year)

