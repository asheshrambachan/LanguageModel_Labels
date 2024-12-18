import os
import pandas as pd
import numpy as np

REPO_DIR = '.'
DATA_DIR = os.path.join(REPO_DIR, "prediction_headlines/data")
TEMP_DIR = os.path.join(REPO_DIR, "prediction_headlines/temp")


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

def main():
    responses_headline_clean = pd.read_json(os.path.join(TEMP_DIR, 'Embeddings/Responses/responses_headline_clean_part1.jsonl'), lines=True)

    responses_headline_llm_clean_part1 = pd.read_json(os.path.join(TEMP_DIR, 'Embeddings/Responses/responses_headline_llm_clean_part1.jsonl'), lines=True)
    responses_headline_llm_clean_part2 = pd.read_json(os.path.join(TEMP_DIR, 'Embeddings/Responses/responses_headline_llm_clean_part2.jsonl'), lines=True)
    responses_headline_llm = pd.concat([responses_headline_llm_clean_part1, responses_headline_llm_clean_part2])

    headline_embeddings = decode_embed_responses(responses_headline_clean)
    description_llm_embeddings = decode_embed_responses(responses_headline_llm)

    headline_embeddings.rename(columns={
        'custom_id': 'headline_id',
        'Embeddings': 'headline_clean_embed',
        'Tokens': 'DescriptionCleanTokens'
        }, inplace=True)
    description_llm_embeddings.rename(columns={
        'custom_id': 'id',
        'Embeddings': 'headline_llm_clean_embed',
        'Tokens': 'DescriptionLLMCleanTokens'
        }, inplace=True)

    # Create benchmark
    benchmark = create_random_benchmark(headline_embeddings['headline_clean_embed'], N=len(headline_embeddings), seed=123)

    benchmark_path = os.path.join(DATA_DIR, "benchmark.csv")
    benchmark.to_csv(benchmark_path, index=False)
    print(f"Saved {os.path.basename(benchmark_path)}, n = {len(benchmark)}, at {os.path.dirname(benchmark_path)}")

    # Add similarity columns
    headlines_completion = pd.read_csv(os.path.join(DATA_DIR, f"headlines_completion.csv"))
    headlines_completion = headlines_completion.merge(headline_embeddings, on="headline_id").merge(description_llm_embeddings, on="id")

    headlines_completion["TextSimilarity"] = headlines_completion["headline_clean"] == headlines_completion["headline_llm_clean"]
    headlines_completion["EuclideanDistance"] = headlines_completion.apply(lambda x: euclidean_distance(x["headline_clean_embed"], x["headline_llm_clean_embed"]), axis=1)
    headlines_completion["CosineSimilarity"] = headlines_completion.apply(lambda x: cosine_similarity(x["headline_clean_embed"], x["headline_llm_clean_embed"]), axis=1)

    headline_completion_similarity = headlines_completion[['headline_id', 'prompt_template_id', 'response_format', 'add_date',
    'model', 'temperature', 'max_tokens', 'headline_trim', 'headline_llm',
    'input_tokens', 'output_tokens', 'date', 'headline',
    'company_name', 'headline_clean', 'headline_llm_clean', 'id',
    'TextSimilarity', 'EuclideanDistance', 'CosineSimilarity']]
    headline_completion_similarity_path = os.path.join(DATA_DIR, "headlines_completion.csv")
    headline_completion_similarity.to_csv(headline_completion_similarity_path, index=False)
    print(f"Saved {os.path.basename(headline_completion_similarity_path)}, n = {len(headline_completion_similarity)}, at {os.path.dirname(headline_completion_similarity_path)}")

if __name__ == "__main__":
    main()