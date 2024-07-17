import json
import pandas as pd
import re
import matplotlib.pyplot as plt
import seaborn as sns

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
            data.append(json.loads(line.strip()))
    return data

def extract_company_and_headline(json_str):
    message_content = json_str['body']['messages'][0]['content']
    
    # Extract company name and headline
    company_name = message_content.split("about ")[1].split(":")[0].strip()
    headline = message_content.split("\n\n")[1].strip()
    
    return {'company_name': company_name, 'headline': headline}


input_file_path = 'batch_prompts.jsonl'
output_file_path = 'batch_output.jsonl'
start_line = num_lines = 100

inputs = read_jsonl_from_line(input_file_path, 0)
inputs = [extract_company_and_headline(json_str) for json_str in inputs]
input = pd.DataFrame(inputs)

outputs_plain = read_jsonl(output_file_path, num_lines)
outputs_plain = [output["response"]["body"]["choices"][0]["message"]["content"] for output in outputs_plain]
outputs_plain = [item.split(', ') for item in outputs_plain]

# Convert the list of lists into a DataFrame
output = pd.DataFrame(outputs_plain, columns=['headline type', 'confidence', 'magnitude'])

# Convert numeric columns to float
output['confidence'] = output['confidence'].astype(float)
output['magnitude'] = output['magnitude'].astype(float)
output['headline type'] = output['headline type'].str.lower()

def extract_json(json_str):
    match = re.search(r'\{.*\}', json_str, re.DOTALL)
    if match:
        return json.loads(match.group(0))
    return None

outputs_json = read_jsonl_from_line(output_file_path, start_line)
outputs_json = [output["response"]["body"]["choices"][0]["message"]["content"] for output in outputs_json]
outputs_json = [extract_json(json_str) for json_str in outputs_json]

output = pd.concat([output, pd.DataFrame(outputs_json)], ignore_index=True) 

data = pd.concat([input, output], axis=1)
data['headline type'] = data['headline type'].map({'positive': 2, 'neutral': 1, 'negative': 0})

# Group by 'headline' and calculate the mean for 'confidence', 'magnitude', and 'headline_type'
data_mean = data.groupby('headline').agg({
    'confidence': ['mean', 'std'],
    'magnitude': ['mean', 'std'],
    'headline type': ['mean', 'std']
}).reset_index()
data_mean.columns = ['_'.join(col).strip() for col in data_mean.columns.values]

# Display the resulting DataFrame
print(data_mean)

# Histogram for confidence_mean
sns.histplot(data_mean['magnitude_std'], bins=20, alpha=0.7, label='Mean Confidence')
plt.show()
