import os
import pandas as pd
import numpy as np

REPO_DIR = '.'
DATA_DIR = os.path.join(REPO_DIR, "prediction_legislation/data")

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def euclidean_distance(a, b):
    a = np.array(a)
    b = np.array(b)
    return np.linalg.norm(a - b)

def decode_embed_responses(responses):
    responses = responses.reset_index(drop=True)
    responses_decoded = []
    for _, response in responses.iterrows(): 
        response_out =  response.response['body']['data'][0]
        responses_decoded.append({
            "custom_id": response["custom_id"],
            "Embeddings": response_out['embedding'],
            "Tokens": int(response.response["body"]["usage"]["prompt_tokens"])
        })
    return(pd.json_normalize(responses_decoded))

def create_random_benchmark(data, N=10_000, seed=123):
    samples = data.sample(n=int(2*N), replace=True, random_state=seed).reset_index(drop=True)

    random_pairs = pd.DataFrame({
        "i": samples[:N].reset_index(drop=True),
        "j": samples[N:].reset_index(drop=True)
        }) 

    rand_cosine = random_pairs.apply(lambda x: cosine_similarity(x["i"], x["j"]), axis=1).mean()
    rand_euclidean = random_pairs.apply(lambda x: euclidean_distance(x["i"], x["j"]), axis=1).mean()

    benchmark = pd.DataFrame({
        "Metric": ["CosineSimilarity", "EuclideanDistance"],
        "Benchmark": [rand_cosine, rand_euclidean]
        }) 
    return(benchmark)

def read_and_merge_jsonl_files(input):
    # Extract directory and prefix
    directory = os.path.dirname(input)
    prefix = os.path.basename(input)

    all_data = []

    # Traverse through the directory
    for file in sorted(os.listdir(directory)):
        if file.startswith(prefix) and file.endswith('.jsonl'):
            file_path = os.path.join(directory, file)
            print(f"Reading: {file_path}")
            df = pd.read_json(file_path, lines=True)
            all_data.append(df)

    # Combine all DataFrames into one
    combined_df = pd.concat(all_data, ignore_index=True)
    print(f"Combined DataFrame has {len(combined_df)} rows.")

    return combined_df

def main():
    responses_description = read_and_merge_jsonl_files(os.path.join(DATA_DIR, 'embeddings/responses/responses_DescriptionClean'))
    responses_description_llm = read_and_merge_jsonl_files(os.path.join(DATA_DIR, 'embeddings/responses/responses_DescriptionLLMClean'))

    description_embeddings = decode_embed_responses(responses_description)
    description_llm_embeddings = decode_embed_responses(responses_description_llm)

    description_embeddings.rename(columns={
        'custom_id': 'BillID',
        'Embeddings': 'DescriptionCleanEmbed',
        'Tokens': 'DescriptionCleanTokens'
        }, inplace=True)
    
    description_llm_embeddings.rename(columns={
        'custom_id': 'ID',
        'Embeddings': 'DescriptionLLMCleanEmbed',
        'Tokens': 'DescriptionLLMCleanTokens'
        }, inplace=True)
    
    # Create benchmark
    benchmark = create_random_benchmark(description_embeddings['DescriptionCleanEmbed'], N=10_000, seed=123)
    benchmark_path = os.path.join(DATA_DIR, "benchmark.csv")
    benchmark.to_csv(benchmark_path, index=False)
    print(f"Saved {os.path.basename(benchmark_path)}, n = {len(benchmark)}, at {os.path.dirname(benchmark_path)}")

    # Add similarity columns to bills_completion.csv
    bills_completion_path = os.path.join(DATA_DIR, "bills_completion.csv")
    bills_completion = pd.read_csv(bills_completion_path)
    bills_completion = bills_completion.merge(description_embeddings, on="BillID").merge(description_llm_embeddings, on="ID")

    bills_completion["TextSimilarity"] = bills_completion["DescriptionClean"] == bills_completion["DescriptionLLMClean"]
    bills_completion["EuclideanDistance"] = bills_completion.apply(lambda x: euclidean_distance(x["DescriptionCleanEmbed"], x["DescriptionLLMCleanEmbed"]), axis=1)
    bills_completion["CosineSimilarity"] = bills_completion.apply(lambda x: cosine_similarity(x["DescriptionCleanEmbed"], x["DescriptionLLMCleanEmbed"]), axis=1)

    bills_completion = bills_completion[[
    'ID', 'BillID', 'PromptingStrategyID', 'PromptingStrategyName',
    'ResponseFormat', 'TrimText', 'AddIntrDate', 'Model', 'Temperature',
    'MaxTokens', 'Year', 'Major', 'MajorText', 'Party', 'Chamber', 'DW1', 'PassH', 'PassS', 'Postal', 'IntrDate',
    'DescriptionTrim', 'Description', 'DescriptionLLM', 'DescriptionClean', 'DescriptionLLMClean',
    'CosineSimilarity', 'EuclideanDistance', 'TextSimilarity']]
    bills_completion.to_csv(bills_completion_path, index=False)
    print(f"Saved {os.path.basename(bills_completion_path)}, n = {len(bills_completion)}, at {os.path.dirname(bills_completion_path)}")

if __name__ == "__main__":
    main()