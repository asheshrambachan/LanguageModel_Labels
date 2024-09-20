import os
import pandas as pd
from openai import OpenAI
from dotenv import load_dotenv

# Place API_KEY in the .env file
load_dotenv()
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY')
REPO_DIR = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills_v2"

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

    os.makedirs(os.path.join(out_dir, "responses_batched"), exist_ok=True)
    responses_batched_paths = []
    for _, batch in batches.iterrows():
        file = batch['file']
        batch_id = batch['id']
        part = batch['part']
        batch_status = client.batches.retrieve(batch_id)
        
        if batch_status.status != "completed":
            print(f"Skipping incomplete file = {file}, Batch ID = {batch_id}")
            continue
        
        output_file_id = batch_status.output_file_id
        responses_batched = client.files.content(output_file_id)

        responses_batched_path = os.path.join(out_dir, file.replace("prompts", "responses"))
        responses_batched.write_to_file(responses_batched_path)

        # if not part 1, we correct the ID as it shouldn't start from 1
        if (part!=1):
            responses_batched = pd.read_json(responses_batched_path, lines=True)
            responses_batched["custom_id"] = responses_batched["custom_id"].apply(lambda x: "ID_" + str(int(x[3:]) + int(1000*24))) 
            responses_batched.to_json(responses_batched_path, orient='records', lines=True)

        print(f"Saved {os.path.basename(responses_batched_path)}, n = {len(responses_batched)}, at {os.path.dirname(responses_batched_path)}")
        responses_batched_paths.append(responses_batched_path)

def main():
    data_dir = os.path.join(REPO_DIR, "Data")
    temp_dir = os.path.join(REPO_DIR, "Temp")
    os.makedirs(temp_dir, exist_ok=True)

    batches = pd.read_csv(os.path.join(data_dir, "batches.csv"))
    check_batches_status(batches)
    download_batched_responses(batches, temp_dir)

if __name__ == "__main__":
    main()