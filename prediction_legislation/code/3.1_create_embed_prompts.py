import os
import pandas as pd
import numpy as np
import json
import tiktoken

REPO_DIR = '.'
DATA_DIR = os.path.join(REPO_DIR, "prediction_legislation/data")
TEMP_DIR = os.path.join(REPO_DIR, "prediction_legislation/temp/embeddings")
os.makedirs(TEMP_DIR, exist_ok=True)

def create_embed_requests_generic(df, text_col_name, id_col_name, out_dir, embedding_model="text-embedding-3-small"):
    df = df[[id_col_name, text_col_name]].drop_duplicates()

    requests = []
    for _, row in df.iterrows():
        request = {
            "custom_id": str(row[id_col_name]),
            "method": "POST",
            "url": "/v1/embeddings",
            "body": {
                "input": row[text_col_name],
                "model": embedding_model
            }
        }
        requests.append(request)

    col_path = os.path.join(out_dir, f"requests_{text_col_name}.jsonl")
    with open(col_path, "w") as f:
        for request in requests:
            f.write(json.dumps(request) + "\n")
        print(f"Saved {os.path.basename(col_path)}, n = {len(requests)}, at {os.path.dirname(col_path)}")

    return({
        'file': col_path,
        'col_name': text_col_name
    })

def create_embed_requests(df, out_dir, embedding_model="text-embedding-3-small"):
    batches = []
    batches.append(create_embed_requests_generic(df, "DescriptionClean", "BillID", out_dir, embedding_model))
    batches.append(create_embed_requests_generic(df, "DescriptionLLMClean", "ID", out_dir, embedding_model))
    return(pd.json_normalize(batches))

def count_tokens(text, model="text-embedding-3-small"):
    encoding = tiktoken.encoding_for_model(model)
    n_tokens = len(encoding.encode(text)) 
    return(n_tokens)

def estimate_cost(descriptions, model="text-embedding-3-small", batched=True):
    n_tokens = np.zeros_like(descriptions)
    for i in range(len(descriptions)):
        n_tokens[i] = count_tokens(descriptions[i], model)
    
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

    bills_completion = pd.read_csv(os.path.join(DATA_DIR, "bills_completion.csv"))

    # Estimate cost using Batch API
    cost_description = estimate_cost(bills_completion["DescriptionClean"].unique(), batched=True)
    print(f"Estimated cost to embed Description using Batch API is ${cost_description:.2f}")
    cost_description_llm = estimate_cost(bills_completion["DescriptionLLMClean"], batched=True)
    print(f"Estimated cost to embed DescriptionLLM using Batch API is ${cost_description_llm:.2f}")

    # Create prompts
    batches = create_embed_requests(bills_completion, requests_dir, embedding_model="text-embedding-3-small")
    batches_path = os.path.join(TEMP_DIR, "batches.csv")
    batches.to_csv(batches_path, index=False)
    print(f"Created batched prompts with batch details stored at {os.path.basename(batches_path)}, n = {len(batches)}, at {os.path.dirname(batches_path)}")

if __name__ == "__main__":
    main()
