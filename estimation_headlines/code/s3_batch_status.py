import os
import pandas as pd
import time
from constants import API_KEY, step2_path, step3_path
from s2_batch_prompt import initialize_client

def retrieve_batch_status(client, id):
    """Retrieves the status of a batch from OpenAI's servers."""
    return client.batches.retrieve(id)

def get_batch_description(batch):
    """Retrieves the description of a batch."""
    description = batch.metadata["description"].split(" ")
    model = description[0]
    question = description[1]
    year = description[3]

    if len(description) == 4:
        part = description[4]
        month = description[2] + part
    else:
        month = description[2]
    
    return model, question, month, year

def download_batch_output(client, output_file_id, output_file_path):
    """Downloads the output of a batch and writes it to a file."""
    file_response = client.files.content(output_file_id)
    file_response.write_to_file(output_file_path)

def download_completed_batches(client, batch_metadata):
    for _, row in batch_metadata.iterrows():

        batch_id = row["batch_id"]
        model = row["model"]
        question = row["question"]
        month = row["month"]
        year = row["year"]

        batch = client.batches.retrieve(batch_id)
        if batch.status != "completed":
            print(f"Skipping Batch ID = {batch_id}")
            continue

        output_file_id = batch.output_file_id
        output_file_path = os.path.join(step3_path, model, f'q{question}', f'q{question}_{month}{year}_responses.jsonl')
    
        download_batch_output(client, output_file_id, output_file_path)
        print(f"Batch output saved to {output_file_path}")

def check_batches_status(client, batches):
    complete = False
    for _, batch in batches.iterrows():
        id = batch['batch_id']
        batch_status = client.batches.retrieve(id)
        if (batch_status.status in ["failed", "cancelled", "expired", "completed"]):
            complete = True
        print(f"{id}: {batch_status.status}")
    return(complete)

def main():
    """Main function to download batch outputs."""
    client = initialize_client(API_KEY)
    batches = pd.read_csv("./data/step2_batch_ids/batch_data.csv")

    print("Checking batch completion status")
    status = check_batches_status(client, batches)
    print(status)
    while (status==False):
        print("sleeping for 15 minutes to allow batches to complete")
        time.sleep(15*60) 
        status = check_batches_status(client, batches)
    
    download_completed_batches(client, batches)

if __name__ == "__main__":
    main()