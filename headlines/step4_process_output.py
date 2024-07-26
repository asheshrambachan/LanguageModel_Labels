import json
import pandas as pd
import re
import matplotlib.pyplot as plt
import seaborn as sns
from step0_constants import personas, thought_modifiers

QUESTION = "1"
MONTH = "feb"
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
    message_content = json_str['body']['messages'][0]['content']
    
    # Extract company name and headline
    company_name = message_content.split("news about ")[1].split(":")[0].strip()
    headline = message_content.split("\n\n")[1].strip()

    type = 0
    if "fill" in message_content:
        type = 1
    for i in range(len(personas)):
        if personas[i] in message_content:
            type = i + 2
    for j in range(len(thought_modifiers)):
        if thought_modifiers[j] in message_content:
            type = j + 2 + len(personas)
    
    return {'company_name': company_name, 'headline': headline, 'prompt_type': type}

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

input_file_path = f'./{MONTH}{YEAR}/q{QUESTION}_prompts.jsonl'
output_file_path = f'./{MONTH}{YEAR}/q{QUESTION}_responses.jsonl'

inputs = read_jsonl_from_line(input_file_path, 0)
inputs = [extract_prompt_info(json_str) for json_str in inputs]
input = pd.DataFrame(inputs)

start_line = num_lines = len(input)/9

outputs_plain = read_jsonl(output_file_path, num_lines)
outputs_plain = [output["response"]["body"]["choices"][0]["message"]["content"] for output in outputs_plain]
outputs_plain = [item.split(', ') for item in outputs_plain]
outputs_plain = [item + [None] * (4 - len(item)) for item in outputs_plain]

# Convert the list of lists into a DataFrame
output = pd.DataFrame(outputs_plain, columns=['headline type', 'confidence', 'magnitude', 'explanation'])

# get json outputs
outputs_json = read_jsonl_from_line(output_file_path, start_line)
outputs_json = [output["response"]["body"]["choices"][0]["message"]["content"] for output in outputs_json]
outputs_json = [extract_json(json_str) for json_str in outputs_json]
outputs_json = [output if output is not None else {"headline type": None} for output in outputs_json]

keys = set().union(*(d.keys() for d in outputs_json))
outputs_json = [{key: d.get(key, None) for key in keys} for d in outputs_json]
output = pd.concat([output, pd.DataFrame(outputs_json)], ignore_index=True) 

data = pd.concat([input, output], axis=1)
data['headline type'] = data['headline type'].str.lower()
data['explanation'] = data['explanation'].str.lower()

# Remove rows where 'headline type' is not valid (not in valid_headlines)
valid_headlines = ['positive', 'neutral', 'negative'] if QUESTION == "1" else ['increase', 'uncertain', 'decrease']
data.loc[~data['headline type'].isin(valid_headlines), 'headline type'] = None
data['headline type num'] = data['headline type'].map({'positive': 2, 'neutral': 1, 'negative': 0}) if QUESTION == "1" else data['headline type'].map({'increase': 2, 'uncertain': 1, 'decrease': 0})

data['confidence'] = pd.to_numeric(data['confidence'], errors='coerce')
data['magnitude'] = pd.to_numeric(data['magnitude'], errors='coerce')
data.loc[~data['confidence'].between(0, 1), 'confidence'] = None
data.loc[~data['magnitude'].between(0, 1), 'magnitude'] = None

# Group by 'headline' and calculate the mean for 'confidence', 'magnitude', and 'headline_type'
data_mean = data.groupby('headline').agg({
    'confidence': ['mean', 'std', 'nunique'],
    'magnitude': ['mean', 'std', 'nunique'],
    'headline type num': ['mean', 'std', 'nunique']
}).reset_index()

data_mean.columns = ['_'.join(col).strip() for col in data_mean.columns.values]

# plt.hist(data_mean['headline type num_nunique'], bins=20)
# plt.show()

# data_mean.to_csv("dec19_output_summary.csv")
data.to_csv(f"./{MONTH}{YEAR}/q{QUESTION}_processed.csv")
