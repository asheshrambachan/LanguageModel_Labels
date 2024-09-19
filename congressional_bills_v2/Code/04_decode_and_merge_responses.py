import os
import glob
import pandas as pd
import json
import re
import matplotlib.pyplot as plt

repo_dir = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills_v2"

data_dir = os.path.join(repo_dir, "Data")

temp_dir = os.path.join(repo_dir, "Temp")
os.makedirs(temp_dir, exist_ok=True)

fig_dir = os.path.join(repo_dir, "Figures and Tables")
os.makedirs(fig_dir, exist_ok=True)

# Create the MAJOR_TEXT dictionary
MAJOR_TEXT = pd.read_csv(os.path.join(data_dir, "Codebooks/major_topics.csv")).set_index('Major')['MajorText'].to_dict()

# Decode Responses
prompts_path = os.path.join(temp_dir, f"prompts.jsonl")
responses_path = os.path.join(temp_dir, f"responses.jsonl")

responses_batched = []
for responses_batched_path in sorted(glob.glob(os.path.join(temp_dir, f'responses_batched_*.jsonl'))):
    responses_batched_file = pd.read_json(responses_batched_path, lines=True)
    print(f"Loaded {responses_batched_path}, n = {len(responses_batched_file)}")
    responses_batched_file["ID"] = responses_batched_file["custom_id"].apply(lambda x: int(x[3:]))
    responses_batched.append(responses_batched_file)
responses_batched = pd.concat(responses_batched)
print(f"Appended all responses, n = {len(responses_batched)}")

prompts = pd.read_json(prompts_path, lines=True)[["ID", "BillID", "ResponseFormat", "AddExplanation"]]
responses_batched = responses_batched.merge(prompts, on="ID")
responses_batched.set_index("ID", inplace=True, drop=False)
responses_batched.sort_index(inplace=True)

responses = []
for _, response_batched in responses_batched.iterrows(): 

    response_text = response_batched.response["body"]["choices"][0]["message"]["content"]

    if response_batched["ResponseFormat"]=="JSON":
        temp = json.loads(response_text)
        major = int(temp["Category"])
        response = {
            "ID": response_batched["ID"],
            "MajorLLM": major,
            "MajorTextLLM": MAJOR_TEXT[major],
            "ConfidenceLLM": float(temp["Confidence"]),
            "ExplanationLLM": temp["Explanation"] if response_batched["AddExplanation"] else None
        }

    else:
        single_entry_pattern = r'^(\d+)\s*[,]{0,1}\s*[\r\n]{0,1}\s*([0-9]\.[0-9]{2})\s*[,]{0,1}[\r\n]{0,1}?\s*(.*)?$'
        multiple_entries_pattern = r'((\d+)\s*\.\s*([\d\.]+)\s*\n)' 

        if re.match(single_entry_pattern, response_text):
            match = re.match(single_entry_pattern, response_text)
            major = int(match.group(1))
            response = {
                "ID": response_batched["ID"],
                "MajorLLM": major,
                "MajorTextLLM": MAJOR_TEXT[major],
                "ConfidenceLLM": float(match.group(2)),
                "ExplanationLLM": match.group(3) if response_batched["AddExplanation"] else None
            }
        elif re.findall(multiple_entries_pattern, response_text):
            print("hi")
            matches = re.findall(multiple_entries_pattern, response_text)
            match = max(matches, key=lambda x: float(x[2]))
            major = int(match[1])
            explanation = re.split('\n', response_text)[-1]
            response = {
                "ID": response_batched["ID"],
                "MajorLLM": major,
                "MajorTextLLM": MAJOR_TEXT[major],
                "ConfidenceLLM": float(match[2]),
                "ExplanationLLM": explanation if response_batched["AddExplanation"] else None
            }

    response["InputTokens"] = int(response_batched.response["body"]["usage"]["prompt_tokens"])
    response["OutputTokens"] = int(response_batched.response["body"]["usage"]["completion_tokens"])
    responses.append(response)

with open(responses_path, "w") as f:
    for response in responses:
        f.write(json.dumps(response) + "\n")
print(f"Saved {responses_path}")

# Merge prompts and responses datasets
bills_path = os.path.join(data_dir, f"bills_10k.csv")
prompts_path = os.path.join(temp_dir, f"prompts.jsonl")
responses_path = os.path.join(temp_dir, f"responses.jsonl")

bills_prompts_responses_path = os.path.join(data_dir, f"bills_prompts_responses.csv")

bills = pd.read_csv(bills_path)
prompts = pd.read_json(prompts_path, lines=True)
prompts.drop(columns=["Messages"], inplace=True)
responses = pd.read_json(responses_path, lines=True)

bills_prompts_responses = prompts.merge(responses, on="ID", validate="1:1").merge(bills, on="BillID", validate="m:1", suffixes=("","_y"))
n_bills = len(bills_prompts_responses['BillID'].unique())
n_prompts = len(bills_prompts_responses)
print(f"Merged bills, prompts and responses, n_bills = {n_bills}, n_prompts = {n_prompts}")

columns2keep = [not col.endswith('_y') for col in bills_prompts_responses.columns]
bills_prompts_responses = bills_prompts_responses.loc[:, columns2keep]
print(f"Dropped unused/duplicated columns.")

bills_prompts_responses.to_csv(bills_prompts_responses_path, index=False)
print(f"Saved merged data at {bills_prompts_responses_path}")

# Figures
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

bills_prompts_responses = pd.read_csv(bills_prompts_responses_path)
bills_prompts_responses["CorrectMajorLLM"] = bills_prompts_responses["Major"] == bills_prompts_responses["MajorLLM"]
stat = bills_prompts_responses.groupby(["PromptingStrategyID", "PromptingStrategyName", "Model"]).agg(
    ShareCorrectMajorLLM = ("CorrectMajorLLM", "mean")
).reset_index().pivot(index='PromptingStrategyID', columns='Model', values='ShareCorrectMajorLLM').plot(
    kind="bar", 
    title=f'Accuracy of LLM major topic labels',
    xlabel='Prompt Modification',
    ylabel='Share of bills with correct LLM major topic label',
    ylim=(0,1)) 

plt.savefig(os.path.join(fig_dir, 'Accuracy of LLM major topic labels.png'))