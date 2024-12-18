import os
import pandas as pd
import numpy as np

REPO_DIR = '.'
DATA_DIR = os.path.join(REPO_DIR, "prediction_cb/data")
TEMP_DIR = os.path.join(REPO_DIR, "prediction_cb/temp/Embeddings")

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def euclidean_distance(a, b):
    a = np.array(a)
    b = np.array(b)
    return np.linalg.norm(a - b)

def decode_embed_responses(responses):
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


def main():
    responses_description_path = os.path.join(TEMP_DIR, 'Responses/responses_DescriptionClean.jsonl')
    responses_description_llm_path = os.path.join(TEMP_DIR, 'Responses/responses_DescriptionLLMClean.jsonl')

    description_embeddings = decode_embed_responses(pd.read_json(responses_description_path, lines=True))
    description_llm_embeddings = decode_embed_responses(pd.read_json(responses_description_llm_path, lines=True))

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

    # Add similarity columns to bills_llm_completion.csv
    bills_llm_completion = pd.read_csv(os.path.join(DATA_DIR, f"bills_llm_completion.csv"))
    bills_llm_completion = bills_llm_completion.merge(description_embeddings, on="BillID").merge(description_llm_embeddings, on="ID")

    bills_llm_completion["TextSimilarity"] = bills_llm_completion["DescriptionClean"] == bills_llm_completion["DescriptionLLMClean"]
    bills_llm_completion["EuclideanDistance"] = bills_llm_completion.apply(lambda x: euclidean_distance(x["DescriptionCleanEmbed"], x["DescriptionLLMCleanEmbed"]), axis=1)
    bills_llm_completion["CosineSimilarity"] = bills_llm_completion.apply(lambda x: cosine_similarity(x["DescriptionCleanEmbed"], x["DescriptionLLMCleanEmbed"]), axis=1)

    bills_llm_completion_similarity = bills_llm_completion[[
    'ID', 'BillID', 'PromptingStrategyID', 'PromptingStrategyName',
    'ResponseFormat', 'TrimText', 'AddIntrDate', 'Model', 'Temperature',
    'MaxTokens', 'Year', 'Major', 'MajorText', 'Party', 'Chamber', 'DW1', 'PassH', 'PassS', 'Postal', 'IntrDate',
    'DescriptionTrim', 'Description', 'DescriptionLLM', 'DescriptionClean', 'DescriptionLLMClean',
    'CosineSimilarity', 'EuclideanDistance', 'TextSimilarity']]
    bills_llm_completion_similarity_path = os.path.join(DATA_DIR, "bills_llm_completion.csv")
    bills_llm_completion_similarity.to_csv(bills_llm_completion_similarity_path, index=False)
    print(f"Saved {os.path.basename(bills_llm_completion_similarity_path)}, n = {len(bills_llm_completion_similarity)}, at {os.path.dirname(bills_llm_completion_similarity_path)}")

if __name__ == "__main__":
    main()