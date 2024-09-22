import os
import glob
import pandas as pd
import json
import re
import matplotlib.pyplot as plt

REPO_DIR = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills_v2"
MAJOR_CODE = pd.read_csv(os.path.join(REPO_DIR, "Data/Codebooks/major_topics.csv")).set_index('Major')['MajorText'].to_dict()

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
    for _, response_batched in responses.iterrows(): 
        response_text = response_batched.response["body"]["choices"][0]["message"]["content"]

        if response_batched["ResponseFormat"]=="JSON":
            temp = json.loads(response_text)
            major = int(temp["Category"])
            confidence = float(temp["Confidence"])
            explanation = temp["Explanation"] if response_batched["AddExplanation"] else None
        else:
            pattern = r'^(\d+)\s*[,]{0,1}\s*[\r\n]{0,1}\s*([0-9]\.[0-9]{2})\s*[,]{0,1}[\r\n]{0,1}?\s*(.*)?$'
            match = re.match(pattern, response_text)
            major = int(match.group(1))
            confidence = float(match.group(2))
            explanation = match.group(3) if response_batched["AddExplanation"] else None

        response = {
            "ID": response_batched["ID"],
            "MajorLLM": major,
            "MajorTextLLM": MAJOR_CODE[major],
            "ConfidenceLLM": confidence,
            "ExplanationLLM": explanation,
            "InputTokens": int(response_batched.response["body"]["usage"]["prompt_tokens"]),
            "OutputTokens": int(response_batched.response["body"]["usage"]["completion_tokens"])
        }
        responses_decoded.append(response)
    return(responses_decoded)

def main():
    data_dir = os.path.join(REPO_DIR, "Data")
    temp_dir = os.path.join(REPO_DIR, "Temp")
    fig_dir = os.path.join(REPO_DIR, "Figures and Tables")
    os.makedirs(temp_dir, exist_ok=True)
    os.makedirs(fig_dir, exist_ok=True)

    bills = pd.read_csv(os.path.join(data_dir, f"bills_10k.csv"))
    prompts = pd.read_json(os.path.join(temp_dir, f"prompts.jsonl"), lines=True) 
    prompts.drop(columns=["Messages"], inplace=True)

    responses_batched_paths = glob.glob(os.path.join(temp_dir, f'responses_batched/*.jsonl'))
    responses = merge_batched_responses(responses_batched_paths)
    print(f"Appended all responses, n = {len(responses)}")

    responses = responses.merge(prompts[["ID", "BillID", "ResponseFormat", "AddExplanation"]], on="ID")
    responses.set_index("ID", inplace=True, drop=False)
    responses.sort_index(inplace=True)

    responses = decode_responses(responses)
    responses_path = os.path.join(temp_dir, f"responses.jsonl")
    with open(responses_path, "w") as f:
        for response in responses:
            f.write(json.dumps(response) + "\n")
    print(f"Saved {responses_path}")

    # Merge prompts and responses datasets
    responses = pd.read_json(os.path.join(temp_dir, f"responses.jsonl"), lines=True)

    bills_prompts_responses = prompts.merge(responses, on="ID", validate="1:1").merge(bills, on="BillID", validate="m:1")
    bills_prompts_responses.to_csv(os.path.join(data_dir, f"bills_prompts_responses.csv"), index=False)
    print(f"Saved bills_prompts_responses.csv, n = {len(bills_prompts_responses)}, at {data_dir}")

    # Figures
    n_bills = len(bills_prompts_responses['BillID'].unique())
    stat = bills_prompts_responses.groupby(["Model","BillID"]).agg(
            UniqueMajorLLM = ("MajorLLM", "nunique")
            ).groupby(["Model","UniqueMajorLLM"]).size().reset_index(name='Count')
    stat['Share'] = stat['Count']/n_bills
    stat.pivot(index='UniqueMajorLLM', columns='Model', values='Share').plot(
        kind="bar", 
        title=f"Histogram of unique LLM labels across all prompt modifications",
        xlabel="Number of unique LLM major topic labels",
        ylabel="Share of Bills")
    plt.savefig(os.path.join(fig_dir, 'A histogram of unique LLM labels across all prompt modifications.png'))

    stat = bills_prompts_responses[bills_prompts_responses["PromptingStrategyName"]=="Few-Shot"].groupby(["Model","BillID"]).agg(
            UniqueMajorLLM = ("MajorLLM", "nunique")
            ).groupby(["Model","UniqueMajorLLM"]).size().reset_index(name='Count')
    stat['Share'] = stat['Count']/n_bills
    stat.pivot(index='UniqueMajorLLM', columns='Model', values='Share').plot(
        kind="bar", 
        title=f"Histogram of unique LLM labels in few-shot prompts",
        xlabel="Number of unique LLM major topic labels",
        ylabel="Share of Bills")
    plt.savefig(os.path.join(fig_dir, 'A histogram of unique LLM labels in few-shot prompts only.png'))

if __name__ == "__main__":
    main()
