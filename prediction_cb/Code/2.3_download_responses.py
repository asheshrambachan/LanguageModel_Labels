import os
import pandas as pd
from openai import OpenAI
from dotenv import load_dotenv

# Place API_KEY in the .env file or replace os.environ.get('OPENAI_API_KEY') with the key
load_dotenv()
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY')
REPO_DIR = "./prediction_cb"

# Check status of all batches
def check_batches_status(batches):
    client = OpenAI(api_key=OPENAI_API_KEY)
    for _, batch in batches.iterrows():
        file = batch['file']
        id = batch['id']
        batch_status = client.batches.retrieve(id)
        print(f"{os.path.basename(file):>52s}: {batch_status.status}")

def download_batched_responses(batches, out_dir):
    client = OpenAI(api_key=OPENAI_API_KEY)

    for _, batch in batches.iterrows():
        batch_id = batch['id']
        model = batch['model']
        part = batch['part']
        responses_batched_path = os.path.join(out_dir, f"responses_batched_{model}_part{part}.jsonl")

        batch_status = client.batches.retrieve(batch_id)
        if batch_status.status != "completed":
            print(f"Skipping incomplete file = {os.path.basename(responses_batched_path)}, Batch ID = {batch_id}")
            continue
        
        output_file_id = batch_status.output_file_id
        responses_batched = client.files.content(output_file_id)

        responses_batched.write_to_file(responses_batched_path)
        print(f"Saved {os.path.basename(responses_batched_path)} at {os.path.dirname(responses_batched_path)}")

def main():
    temp_dir = os.path.join(REPO_DIR, "Temp/LLM")
    batched_responses_dir = os.path.join(temp_dir, "responses_batched")
    os.makedirs(batched_responses_dir, exist_ok=True)

    batches = pd.read_csv(os.path.join(temp_dir, "batches.csv"))
    check_batches_status(batches)
    download_batched_responses(batches, batched_responses_dir)

if __name__ == "__main__":
    main()