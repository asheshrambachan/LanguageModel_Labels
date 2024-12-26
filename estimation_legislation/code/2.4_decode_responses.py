import os
import glob
import pandas as pd
import json
import re

REPO_DIR = '.'
DATA_DIR = os.path.join(REPO_DIR, "estimation_legislation/data")

MAJOR_CODE = pd.read_csv(os.path.join(DATA_DIR, "major_topics.csv")).set_index('Major')['MajorText'].to_dict()

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
    return(pd.json_normalize(responses_decoded))

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
    bills = pd.read_csv(os.path.join(DATA_DIR, f"bills.csv"))
    prompts = read_and_merge_jsonl_files(os.path.join(DATA_DIR, f"llm/prompts")) 
    prompts.drop(columns=["Messages"], inplace=True)

    # Load and merge batched responses
    responses = read_and_merge_jsonl_files(os.path.join(DATA_DIR, f"llm/responses_batched/responses_batched"))
    responses["ID"] = responses["custom_id"].apply(lambda x: int(x[3:]))
    print(f"Appended all responses, n = {len(responses)}")
    responses = responses.merge(prompts[["ID", "BillID", "ResponseFormat", "AddExplanation"]], on="ID")
    responses.set_index("ID", inplace=True, drop=False)
    responses.sort_index(inplace=True)

    # Decoded responses and save aas jsonl file
    responses = decode_responses(responses)
    
    # Merge prompts and bills metadata with llm responses
    bills_llm = prompts.merge(responses, on="ID", validate="1:1").merge(bills, on="BillID", validate="m:1")
    bills_llm_path = os.path.join(DATA_DIR, f"bills_llm.csv")
    bills_llm.to_csv(bills_llm_path, index=False)
    print(f"Saved {os.path.basename(bills_llm_path)}, n = {len(bills_llm)}, at {os.path.dirname(bills_llm_path)}")

if __name__ == "__main__":
    main()
