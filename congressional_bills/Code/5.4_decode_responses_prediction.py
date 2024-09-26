import os
import glob
import pandas as pd
import json
import re

REPO_DIR = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills"

def merge_batched_responses(responses_batched_paths):
    responses = []
    for responses_batched_path in sorted(responses_batched_paths):
        responses_batched_file = pd.read_json(responses_batched_path, lines=True)
        print(f"Loaded {os.path.basename(responses_batched_path)}, n = {len(responses_batched_file)}")
        responses_batched_file["ID"] = responses_batched_file["custom_id"].apply(lambda x: int(x[3:]))
        responses.append(responses_batched_file)
    responses = pd.concat(responses)
    return(responses)

def decode_responses_passage(responses):
    responses_decoded = []
    for _, response in responses.iterrows(): 
        response_text = response.response["body"]["choices"][0]["message"]["content"]
        response_json = json.loads(response_text)

        responses_decoded.append({
            "ID": response["ID"],
            "PassSLLM": int(response_json["PassSLLM"]),
            "PassHLLM": int(response_json["PassHLLM"]),
            "InputTokens": int(response.response["body"]["usage"]["prompt_tokens"]),
            "OutputTokens": int(response.response["body"]["usage"]["completion_tokens"])
        })
    return(responses_decoded)

def decode_responses_completion(responses):
    responses_decoded = []
    for _, response in responses.iterrows(): 
        response_text = response.response["body"]["choices"][0]["message"]["content"]
        response_json = json.loads(response_text)
        responses_decoded.append({
            "ID": response["ID"],
            "DescriptionLLM": response_json["DescriptionLLM"],
            "InputTokens": int(response.response["body"]["usage"]["prompt_tokens"]),
            "OutputTokens": int(response.response["body"]["usage"]["completion_tokens"])
        })
    return(responses_decoded)

def count_words(description):
    words = description.split() # Split the description into words
    word_count = len(words) # Total number of words
    return word_count

def main():
    data_dir = os.path.join(REPO_DIR, "Data")
    temp_dir = os.path.join(REPO_DIR, "Temp")
    os.makedirs(temp_dir, exist_ok=True)

    bills = pd.read_csv(os.path.join(data_dir, f"bills.csv"))
    prompts = pd.read_json(os.path.join(temp_dir, f"prompts_prediction.jsonl"), lines=True) 
    prompts.drop(columns=["Messages"], inplace=True)

    # Load and merge batched responses
    responses_batched_paths = glob.glob(os.path.join(temp_dir, f'responses_batched_prediction/*.jsonl'))
    responses = merge_batched_responses(responses_batched_paths)
    
    print(f"Appended all responses, n = {len(responses)}")
    responses = responses.merge(prompts[["ID",  "PromptingStrategyID", "PromptingStrategyName", "BillID", "TrimText", "AddIntrYear"]], on="ID")
    responses.set_index("ID", inplace=True, drop=False)
    responses.sort_index(inplace=True)

    responses_passage = responses.loc[responses["PromptingStrategyName"]=="Predict Bill Passage"]
    responses_completion = responses.loc[responses["PromptingStrategyName"]=="Complete Bill Summary"]
    # print(len(responses_passage))

    # Decoded responses
    responses_passage = decode_responses_passage(responses_passage)
    responses_completion = decode_responses_completion(responses_completion)

    # save as jsonl file
    responses_passage_path = os.path.join(temp_dir, f"responses_prediction_passage.jsonl")
    with open(responses_passage_path, "w") as f:
        for response in responses_passage:
            f.write(json.dumps(response) + "\n")
    print(f"Saved {os.path.basename(responses_passage_path)}, at {os.path.dirname(responses_passage_path)}")

    responses_completion_path = os.path.join(temp_dir, f"responses_prediction_completion.jsonl")
    with open(responses_completion_path, "w") as f:
        for response in responses_completion:
            f.write(json.dumps(response) + "\n")
    print(f"Saved {os.path.basename(responses_completion_path)}, at {os.path.dirname(responses_completion_path)}")

    # Merge prompts and bills metadata with llm responses
    responses_passage = pd.read_json(responses_passage_path, lines=True)
    bills_llm_passage = prompts.merge(responses_passage, on="ID", validate="1:1").merge(bills, on="BillID", validate="m:1")

    responses_completion = pd.read_json(responses_completion_path, lines=True)
    bills_llm_completion = prompts.merge(responses_completion, on="ID", validate="1:1").merge(bills, on="BillID", validate="m:1")

    # Print mean and max input and output tokens
    print("bills_llm_passage")
    print(bills_llm_passage[["AddIntrYear", "InputTokens", "OutputTokens"]].groupby("AddIntrYear").agg(['mean', 'max']))

    print("bills_llm_completion")
    bills_llm_completion["OutputWords"] = bills_llm_completion["DescriptionLLM"].apply(count_words)
    print(bills_llm_completion[["AddIntrYear", "InputTokens", "OutputTokens", "OutputWords"]].groupby("AddIntrYear").agg(['mean', 'max']))

    # Save
    bills_llm_passage_path = os.path.join(data_dir, f"bills_llm_passage.csv")
    bills_llm_passage.to_csv(bills_llm_passage_path, index=False)
    print(f"Saved {os.path.basename(bills_llm_passage_path)}, n = {len(bills_llm_passage)}, at {os.path.dirname(bills_llm_passage_path)}")

    bills_llm_completion_path = os.path.join(data_dir, f"bills_llm_completion.csv")
    bills_llm_completion.to_csv(bills_llm_completion_path, index=False)
    print(f"Saved {os.path.basename(bills_llm_completion_path)}, n = {len(bills_llm_completion)}, at {os.path.dirname(bills_llm_completion_path)}")

if __name__ == "__main__":
    main()
