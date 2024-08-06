from openai import OpenAI
from step0_constants import API_KEY

def initialize_client(api_key):
    """
    Initializes the OpenAI client with the provided API key.
    
    Parameters:
    - api_key (str): The API key for OpenAI.

    Returns:
    - client (OpenAI): Initialized OpenAI client.
    """
    return OpenAI(api_key=api_key)

def retrieve_batch_status(client, batch_id):
    """
    Retrieves the status of a batch from OpenAI's servers.
    
    Parameters:
    - client (OpenAI): The OpenAI client.
    - batch_id (str): The ID of the batch to retrieve.

    Returns:
    - batch (dict): The retrieved batch object.
    """
    return client.batches.retrieve(batch_id)

def download_batch_output(client, output_file_id, output_file_path):
    """
    Downloads the output of a batch and writes it to a file.
    
    Parameters:
    - client (OpenAI): The OpenAI client.
    - output_file_id (str): The ID of the output file to download.
    - output_file_path (str): The path where the output file will be saved.
    """
    file_response = client.files.content(output_file_id)
    file_response.write_to_file(output_file_path)

def main(batch_id, output_file_path):
    client = initialize_client(API_KEY)
    batch = retrieve_batch_status(client, batch_id)
    output_file_id = batch.output_file_id
    download_batch_output(client, output_file_id, output_file_path)

if __name__ == "__main__":
    # Example usage
    batch_id = "batch_rR9AfyeOEq6VAUSMnF6j1Zcl"  # Replace with your batch ID
    output_file_path = "batch_dec19_output.jsonl"  # Replace with your desired output file path
    main(batch_id, output_file_path)