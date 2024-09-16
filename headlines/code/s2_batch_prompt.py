from openai import OpenAI
from s0_constants import API_KEY, economic_questions, month_batches, models, years

def initialize_client(api_key):
    """
    Initializes the OpenAI client with the provided API key.
    
    Parameters:
    - api_key (str): The API key for OpenAI.

    Returns:
    - client (OpenAI): Initialized OpenAI client.
    """
    return OpenAI(api_key=api_key)

def create_batch_input_file(client, file_path):
    """
    Creates a batch input file on OpenAI's servers.
    
    Parameters:
    - client (OpenAI): The OpenAI client.
    - file_path (str): The path to the local file to upload.

    Returns:
    - batch_input_file_id (str): The ID of the created batch input file.
    """
    with open(file_path, "rb") as file:
        batch_input_file = client.files.create(
            file=file,
            purpose="batch"
        )
    return batch_input_file.id

def create_batch(client, batch_input_file_id, description):
    """
    Creates a batch on OpenAI's servers.
    
    Parameters:
    - client (OpenAI): The OpenAI client.
    - batch_input_file_id (str): The ID of the batch input file.
    - description (str): Description for the batch metadata.

    Returns:
    - batch (dict): The created batch object.
    """
    batch = client.batches.create(
        input_file_id=batch_input_file_id,
        endpoint="/v1/chat/completions",
        completion_window="24h",
        metadata={
            "description": description
        }
    )
    return batch

def main(question, model, month, year):

    description = model + " " + question + " " + month + " " + year
    
    file_path = f'./data/step1_batch_prompts/{model}/q{question}/q{question}_{month}{year}_prompts.jsonl'
    client = initialize_client(API_KEY)
    batch_input_file_id = create_batch_input_file(client, file_path)
    batch = create_batch(client, batch_input_file_id, description=description)
    print(batch)

if __name__ == "__main__":
    for question in economic_questions:
        for model in models:
            for month in month_batches:
                for year in years:
                    main(question, model, month, year)

