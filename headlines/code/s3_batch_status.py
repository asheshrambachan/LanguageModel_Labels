import os
from s0_constants import API_KEY, step2_path
from s2_batch_prompt import initialize_client

def retrieve_batch_status(client, batch_id):
    """Retrieves the status of a batch from OpenAI's servers."""
    return client.batches.retrieve(batch_id)

def get_batch_description(client, batch):
    """Retrieves the description of a batch."""

    description = batch.metadata["description"].split(" ")
    model = description[0]
    question = description[1]
    month = description[2]
    year = description[3]
    
    return model, question, month, year

def download_batch_output(client, output_file_id, output_file_path):
    """Downloads the output of a batch and writes it to a file."""
    file_response = client.files.content(output_file_id)
    file_response.write_to_file(output_file_path)

def main(batch_id):
    """Main function to download the output of a batch."""
    client = initialize_client(API_KEY)
    batch = retrieve_batch_status(client, batch_id)
    model, question, month, year = get_batch_description(batch)
    
    output_file_id = batch.output_file_id
    output_file_path = os.path.join(step2_path, model, f'q{question}', f'q{question}_{month}{year}_responses.jsonl')
    
    download_batch_output(client, output_file_id, output_file_path)
    print(f"Batch output saved to {output_file_path}")

if __name__ == "__main__":
    batch_id = "batch_rR9AfyeOEq6VAUSMnF6j1Zcl"  # Replace with your batch ID
    main(batch_id)