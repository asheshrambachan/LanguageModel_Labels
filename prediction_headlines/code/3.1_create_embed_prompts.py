import os
import pandas as pd
import numpy as np
import json
import tiktoken

REPO_DIR = '.'
DATA_DIR = os.path.join(REPO_DIR, "prediction_headlines/data")
TEMP_DIR = os.path.join(REPO_DIR, "prediction_headlines/temp/embeddings")

os.chdir(REPO_DIR)
PER_BATCH_LIMIT = 50e3 # up to 50,000 requests per batch

def create_embed_requests_generic(df, text_col_name, id_col_name, out_dir, embedding_model="text-embedding-3-small"):

    df = df[[id_col_name, text_col_name]].drop_duplicates().reset_index(drop=True)

    part = 0
    batches = []
    requests = []

    for i, row in df.iterrows():
        requests.append({
            "custom_id": str(row[id_col_name]),
            "method": "POST",
            "url": "/v1/embeddings",
            "body": {
                "input": row[text_col_name],
                "model": embedding_model
            }
        })

        # print(i)
        if ((len(requests)==PER_BATCH_LIMIT) | (i==(len(df)-1))):
            part = part + 1

            col_path = os.path.join(out_dir, f"requests_{text_col_name}_part{part}.jsonl")
            with open(col_path, "w") as f:
                for request in requests:
                    f.write(json.dumps(request) + "\n")
                print(f"Saved {os.path.basename(col_path)}, n = {len(requests)}, at {os.path.dirname(col_path)}")
            requests = []
            batches.append({
                'file': col_path,
                'part': part,
                'col_name': text_col_name
            })

    return(pd.json_normalize(batches))

def create_embed_requests(df, out_dir, embedding_model="text-embedding-3-small"):
    batches = []
    batches.append(create_embed_requests_generic(df, "headline_clean", "headline_id", out_dir, embedding_model))
    batches.append(create_embed_requests_generic(df, "headline_llm_clean", "id", out_dir, embedding_model))
    batches = pd.concat(batches, ignore_index=True)
    return(batches)

def count_tokens(text, model="text-embedding-3-small"):
    encoding = tiktoken.encoding_for_model(model)
    n_tokens = len(encoding.encode(text)) 
    return(n_tokens)

def estimate_cost(text, model="text-embedding-3-small", batched=True):
    n_tokens = np.zeros_like(text)
    for i in range(len(text)):
        n_tokens[i] = count_tokens(text[i], model)
    
    # Cost without using Batch API
    embed_token_cost = {
        'text-embedding-3-small': 0.020/1e6,
        'text-embedding-3-large': 0.130/1e6,
        'ada v2': 0.100/1e6
    }

    total_cost  = (n_tokens * embed_token_cost[model]).sum()
    if batched:
        total_cost = total_cost/2
    return total_cost

def main():
    requests_dir = os.path.join(TEMP_DIR, "requests")
    os.makedirs(requests_dir, exist_ok=True)

    headlines_completion = pd.read_csv(os.path.join(DATA_DIR, "headlines_completion.csv"))

    # Estimate cost using Batch API
    cost_description = estimate_cost(headlines_completion["headline_clean"].unique(), batched=True)
    print(f"Estimated cost to embed headline using Batch API is ${cost_description:.2f}")
    cost_description_llm = estimate_cost(headlines_completion["headline_llm_clean"], batched=True)
    print(f"Estimated cost to embed headline_llm using Batch API is ${cost_description_llm:.2f}")

    # Create prompts
    batches = create_embed_requests(headlines_completion, requests_dir, embedding_model="text-embedding-3-small")
    batches_path = os.path.join(TEMP_DIR, "batches.csv")
    batches.to_csv(batches_path, index=False)
    print(f"Created batched prompts with batch details stored at {os.path.basename(batches_path)}, n = {len(batches)}, at {os.path.dirname(batches_path)}")

if __name__ == "__main__":
    main()