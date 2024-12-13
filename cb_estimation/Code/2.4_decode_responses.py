import os
import glob
import pandas as pd
import json
import re

REPO_DIR = "."
MAJOR_CODE = pd.read_csv(os.path.join(REPO_DIR, "Data/major_topics.csv")).set_index('Major')['MajorText'].to_dict()

def merge_batched_responses(responses_batched_paths):
    responses = []
    for responses_batched_path in sorted(responses_batched_paths):
        responses_batched_file = pd.read_json(responses_batched_path, lines=True)
        # print(f"Loaded {responses_batched_path}, n = {len(responses_batched_file)}")
        responses_batched_file["ID"] = responses_batched_file["custom_id"].apply(lambda x: int(x[3:]))
        responses.append(responses_batched_file)
    responses = pd.concat(responses)
    return(responses)

def decode_responses(responses):
    responses_decoded = []
    for _, response in responses.iterrows(): 
        response_text = response.response["body"]["choices"][0]["message"]["content"]

        if response["ResponseFormat"]=="JSON":
            temp = json.loads(response_text)
            major = int(temp["Category"])
            confidence = float(temp["Confidence"])
            explanation = temp["Explanation"] if response["AddExplanation"] else None
        else:
            pattern = r'^(\d+)\s*[,]{0,1}\s*[\r\n]{0,1}\s*([0-9]\.[0-9]{2})\s*[,]{0,1}[\r\n]{0,1}?\s*(.*)?$'
            match = re.match(pattern, response_text)
            major = int(match.group(1))
            confidence = float(match.group(2))
            explanation = match.group(3) if response["AddExplanation"] else None
        
        responses_decoded.append({
            "ID": response["ID"],
            "MajorLLM": major,
            "MajorTextLLM": MAJOR_CODE[major],
            "ConfidenceLLM": confidence,
            "ExplanationLLM": explanation,
            "InputTokens": int(response.response["body"]["usage"]["prompt_tokens"]),
            "OutputTokens": int(response.response["body"]["usage"]["completion_tokens"])
        })
    return(responses_decoded)

def main():
    data_dir = os.path.join(REPO_DIR, "Data")
    temp_dir = os.path.join(REPO_DIR, "Temp")
    os.makedirs(temp_dir, exist_ok=True)

    bills = pd.read_csv(os.path.join(data_dir, f"bills.csv"))
    prompts = pd.read_json(os.path.join(temp_dir, f"prompts.jsonl"), lines=True) 
    prompts.drop(columns=["Messages"], inplace=True)

    # Load and merge batched responses
    responses_batched_paths = glob.glob(os.path.join(temp_dir, f'responses_batched/*.jsonl'))
    responses = merge_batched_responses(responses_batched_paths)
    print(f"Appended all responses, n = {len(responses)}")
    responses = responses.merge(prompts[["ID", "BillID", "ResponseFormat", "AddExplanation"]], on="ID")
    responses.set_index("ID", inplace=True, drop=False)
    responses.sort_index(inplace=True)

    # Decoded responses and save aas jsonl file
    responses = decode_responses(responses)
    responses_path = os.path.join(temp_dir, f"responses.jsonl")
    with open(responses_path, "w") as f:
        for response in responses:
            f.write(json.dumps(response) + "\n")
    print(f"Saved {responses_path}")

    # Merge prompts and bills metadata with llm responses
    responses = pd.read_json(os.path.join(temp_dir, f"responses.jsonl"), lines=True)
    bills_llm = prompts.merge(responses, on="ID", validate="1:1").merge(bills, on="BillID", validate="m:1")
    bills_llm_path = os.path.join(data_dir, f"bills_llm.csv")
    bills_llm.to_csv(bills_llm_path, index=False)
    print(f"Saved {os.path.basename(bills_llm_path)}, n = {len(bills_llm)}, at {os.path.dirname(bills_llm_path)}")

if __name__ == "__main__":
    main()
