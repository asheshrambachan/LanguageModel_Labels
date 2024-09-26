import os
import pandas as pd
from openai import OpenAI
from dotenv import load_dotenv

# Place API_KEY in the .env file
load_dotenv()
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY')
REPO_DIR = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills"

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
    temp_dir = os.path.join(REPO_DIR, "Temp")

    # Query LLM and store batches id 
    batches = pd.read_csv(os.path.join(temp_dir, "batches.csv"))
    batches = query_llm(batches)
    batches.to_csv(os.path.join(temp_dir, "batches.csv"), index=False)
    print(f"Added batch_id to batches.csv, n = {len(batches)}, at {temp_dir}")

if __name__ == "__main__":
    main()