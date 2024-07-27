import json
import pandas as pd
import re
import matplotlib.pyplot as plt
import seaborn as sns
from step0_constants import personas, thought_modifiers

QUESTION = "5"
MONTH = "apr"
YEAR = "19"

def read_jsonl(file_path, num_lines):
    data = []
    with open(file_path, 'r') as file:
        for i, line in enumerate(file):
            if i >= num_lines:
                break
            data.append(json.loads(line.strip()))
    return data

def read_jsonl_from_line(file_path, start_line):
    data = []
    with open(file_path, 'r') as file:
        for i, line in enumerate(file):
            if i < start_line:
                continue
            try:
                data.append(json.loads(line.strip()))
            except:
                print(line)
    return data

def extract_prompt_info(json_str):
    custom_id = json_str['custom_id']
    message_content = json_str['body']['messages'][0]['content']
    
    # Extract company name and headline
    company_name = message_content.split("news about ")[1].split(":")[0].strip()
    headline = message_content.split("\n\n")[1].strip()

    type = 0
    if "fill in" in message_content:
        type = 1
    for i in range(len(personas)):
        if personas[i] in message_content:
            type = i + 2
    for j in range(len(thought_modifiers)):
        if thought_modifiers[j] in message_content:
            type = j + 2 + len(personas)
    
    return {'custom_id': custom_id, 'company_name': company_name, 'headline': headline, 'prompt_type': type}

def extract_json(json_str):
    match = re.search(r'\{.*\}', json_str, re.DOTALL)
    if match:
        json_text = match.group(0)
        try:
            return json.loads(json_text)
        except:
            print(f"Offending JSON string: {repr(json_text)}")
            return None
    return None

# File paths
input_file_path = f'./{MONTH}{YEAR}/q{QUESTION}_prompts.jsonl'
output_file_path = f'./{MONTH}{YEAR}/q{QUESTION}_responses.jsonl'

# Read and process input data
input_data = read_jsonl_from_line(input_file_path, 0)
input_data = [extract_prompt_info(json_str) for json_str in input_data]
input_df = pd.DataFrame(input_data)
start_line = num_lines = len(input_df) // 9

# Read plain text responses and extract necessary columns
outputs_plain = read_jsonl(output_file_path, num_lines)
outputs_plain_ids = pd.DataFrame([output["custom_id"] for output in outputs_plain], columns=["custom_id"])
outputs_plain = [output["response"]["body"]["choices"][0]["message"]["content"] for output in outputs_plain]
outputs_plain = [item.split(', ') for item in outputs_plain]
outputs_plain = [item + [None] * (4 - len(item)) for item in outputs_plain]
output_cols = ['headline type', 'confidence', 'magnitude', 'explanation']
outputs_plain_df = pd.DataFrame(outputs_plain, columns=output_cols)
outputs_plain_df = pd.concat([outputs_plain_ids, outputs_plain_df], axis=1)

# Read JSON responses and extract necessary columns
outputs_json = read_jsonl_from_line(output_file_path, start_line)
outputs_json_ids = pd.DataFrame([output["custom_id"] for output in outputs_json], columns=["custom_id"])
outputs_json = [output["response"]["body"]["choices"][0]["message"]["content"] for output in outputs_json]
outputs_json = [extract_json(json_str) for json_str in outputs_json]
outputs_json = [output if output is not None else {"headline type": None} for output in outputs_json]
outputs_json = [{key: d.get(key, None) for key in output_cols} for d in outputs_json]
outputs_json_df = pd.DataFrame(outputs_json, columns=output_cols)
outputs_json_df = pd.concat([outputs_json_ids, outputs_json_df], axis=1)

# Combine plain text and JSON responses
combined_output = pd.concat([outputs_plain_df, outputs_json_df], ignore_index=True)

# Merge input data with combined output
data = pd.merge(input_df, combined_output, on='custom_id', how='outer')
data['headline type'] = data['headline type'].str.lower()
data['explanation'] = data['explanation'].str.lower()

# Remove invalid 'headline type' values
valid_headlines = ['positive', 'neutral', 'negative'] if QUESTION == "1" else ['increase', 'uncertain', 'decrease']
data.loc[~data['headline type'].isin(valid_headlines), 'headline type'] = None
data['headline type num'] = data['headline type'].map({'positive': 2, 'neutral': 1, 'negative': 0}) if QUESTION == "1" else data['headline type'].map({'increase': 2, 'uncertain': 1, 'decrease': 0})

# Convert 'confidence' and 'magnitude' to numeric and filter invalid values
data['confidence'] = pd.to_numeric(data['confidence'], errors='coerce')
data['magnitude'] = pd.to_numeric(data['magnitude'], errors='coerce')
data.loc[~data['confidence'].between(0, 1), 'confidence'] = None
data.loc[~data['magnitude'].between(0, 1), 'magnitude'] = None

# Group by 'headline' and calculate statistics
data_mean = data.groupby('headline').agg({
    'confidence': ['mean', 'std', 'nunique'],
    'magnitude': ['mean', 'std', 'nunique'],
    'headline type num': ['mean', 'std', 'nunique']
}).reset_index()

# Flatten MultiIndex columns
data_mean.columns = ['_'.join(col).strip() for col in data_mean.columns.values]

# Save the processed data to a CSV file
data.to_csv(f"./{MONTH}{YEAR}/q{QUESTION}_processed.csv", index=False)

# plt.hist(data_mean['headline type num_nunique'], bins=20)
# plt.show()

# # data_mean.to_csv("dec19_output_summary.csv")