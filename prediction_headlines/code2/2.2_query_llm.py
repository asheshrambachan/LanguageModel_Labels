import os
import pandas as pd
from openai import OpenAI
from dotenv import load_dotenv

REPO_DIR = "."
TEMP_DIR = os.path.join(REPO_DIR, "prediction_headlines/temp/LLM")

# Place API_KEY in the .env file
load_dotenv(os.path.join(REPO_DIR, ".env"), override=True)
OPENAI_API_KEY = os.environ.get('API_KEY')

def query_llm(batches):
    client = OpenAI(api_key=OPENAI_API_KEY)
    
    batches_id = []
    for _, batch in batches.iterrows():
        batch_input_file = client.files.create(
            file = open(batch['file'], "rb"),
            purpose = "batch"
        )

        new_batch = client.batches.create(
            input_file_id = batch_input_file.id,
            endpoint = "/v1/chat/completions",
            completion_window = "24h",
            metadata = {"description": f"{os.path.basename(batch['file'])}"}
        )

        batches_id.append(new_batch.id)
    
    batches['id'] = batches_id
    return(batches)

def main():
    # Query LLM and store batches id 
    batches_path = os.path.join(TEMP_DIR, "batches.csv")
    batches = pd.read_csv(batches_path)
    batches = query_llm(batches)
    batches.to_csv(batches_path, index=False)
    print(f"Added batch_id to {os.path.basename(batches_path)}, n = {len(batches)}, at {os.path.dirname(batches_path)}")

if __name__ == "__main__":
    main()