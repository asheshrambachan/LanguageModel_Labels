from openai import OpenAI
import os
from s0_constants import API_KEY, step1_path

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
    file_path = os.path.join(step1_path, model, f'q{question}', f'q{question}_{month}{year}_prompts.jsonl')

    # Initialize the client and create the batch
    client = initialize_client(API_KEY)
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

