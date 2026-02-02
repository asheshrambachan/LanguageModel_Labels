import os
import pandas as pd
from openai import OpenAI
from dotenv import load_dotenv
import time 

REPO_DIR = "."
TEMP_DIR = os.path.join(REPO_DIR, "prediction_headlines/temp/llm")
DATA_DIR = os.path.join(REPO_DIR, "prediction_headlines/data/llm")

# Place API_KEY in the .env file
load_dotenv(os.path.join(REPO_DIR, ".env"), override=True)
OPENAI_API_KEY = os.environ.get('API_KEY')

# Check status of all batches
def check_batches_status(batches):
	client = OpenAI(api_key=OPENAI_API_KEY)
	status = True
	for _, batch in batches.iterrows():
		file = batch['file']
		id = batch['id']
		batch_status = client.batches.retrieve(id)
		if batch_status.request_counts.total!=0:
			progress = batch_status.request_counts.completed / batch_status.request_counts.total
		else:
			progress = 0
		print(f"{os.path.basename(file):>52s}: {batch_status.status} ({progress:.2%})")
		if (batch_status.status != "completed"):
			status = False
		elif (batch_status.status in ["failed", "cancelled", "expired"]):
			continue
	print()
	return(status)

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

        # if output_file_id is None:
        #     output_file_id = batch_status.error_file_id

        responses_batched = client.files.content(output_file_id)

        responses_batched.write_to_file(responses_batched_path)
        print(f"Saved {os.path.basename(responses_batched_path)} at {os.path.dirname(responses_batched_path)}")

def split_jsonl_file(input_file, output_dir, max_size=100 * 1_000_000):  # 1 MB = 1,000,000 bytes
    """Splits a JSONL file into smaller parts."""
    os.makedirs(output_dir, exist_ok=True)
    base_name = os.path.splitext(os.path.basename(input_file))[0]  # Remove .jsonl
    file_count = 1
    current_size = 0
    output_file = os.path.join(output_dir, f"{base_name}_{file_count}.jsonl")
    output = open(output_file, 'w', encoding='utf-8')
    
    with open(input_file, 'r', encoding='utf-8') as infile:
        for line in infile:
            line_size = len(line.encode('utf-8'))
            if current_size + line_size > max_size:
                output.close()
                file_count += 1
                output_file = os.path.join(output_dir, f"{base_name}_{file_count}.jsonl")
                output = open(output_file, 'w', encoding='utf-8')
                current_size = 0
            
            output.write(line)
            current_size += line_size
    
    output.close()
    print(f"Split completed for {input_file}. Files are saved in {output_dir}")

def split_jsonl_in_directory(input_dir, output_base_dir, max_size=100 * 1_000_000):
    """Splits all JSONL files in a directory recursively."""
    for root, _, files in os.walk(input_dir):
        for file in files:
            if file.endswith('.jsonl'):  # Process only JSONL files
                input_file = os.path.join(root, file)
                relative_path = os.path.relpath(root, input_dir)
                output_dir = os.path.join(output_base_dir, relative_path)
                split_jsonl_file(input_file, output_dir, max_size)

def main():
    batched_responses_dir = os.path.join(TEMP_DIR, "responses_batched")
    os.makedirs(batched_responses_dir, exist_ok=True)

    batches = pd.read_csv(os.path.join(TEMP_DIR, "batches.csv"))

    status = check_batches_status(batches)
    while (status==False):
        time.sleep(15*60) # 15 min
        status = check_batches_status(batches)
        
    download_batched_responses(batches, batched_responses_dir)

    split_jsonl_in_directory(TEMP_DIR, DATA_DIR)

if __name__ == "__main__":
    main()