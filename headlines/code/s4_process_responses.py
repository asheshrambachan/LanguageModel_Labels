import json
import pandas as pd
import os
import re
from constants import personas, thought_modifiers, step1_path, step2_path, step4_path
from constants import economic_questions, models, month_batches, years

def read_jsonl(file_path, num_lines):
    """Reads a specified number of lines from a JSONL file."""
    with open(file_path, 'r') as file:
        return [json.loads(line.strip()) for i, line in enumerate(file) if i < num_lines]

def read_jsonl_from_line(file_path, start_line):
    """Reads a JSONL file starting from a specified line."""
    with open(file_path, 'r') as file:
        return [json.loads(line.strip()) for i, line in enumerate(file) if i >= start_line]

def extract_json(json_str):
    """Extracts the JSON object from the given JSON string."""
    match = re.search(r'\{.*\}', json_str, re.DOTALL)

    if match:
        json_text = match.group(0)
        try:
            return json.loads(json_text)  
        except json.JSONDecodeError:
            explanation_index = json_text.find('"explanation"')
            if explanation_index != -1:
                json_text = json_text[:explanation_index - 2].rstrip(', \n') + "}"
            try:
                return json.loads(json_text)  
            except json.JSONDecodeError:
                return None
    return None

def extract_prompt_info(json_str):
    """Extracts the prompt information from the given JSON string."""
    custom_id = json_str['custom_id']
    message_content = json_str['body']['messages'][0]['content']

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

def construct_file_paths(question, model, month, year):
    """Constructs the input and output file paths based on the given parameters."""
    input_file_path = f'{step1_path}/{model}/q{question}/q{question}_{month}{year}_prompts.jsonl'
    output_file_path = f'{step2_path}/{model}/q{question}/q{question}_{month}{year}_responses.jsonl'
    return input_file_path, output_file_path

def read_and_process_input_data(input_file_path):
    """Reads the input data from the given input file path and processes it."""
    input_data = read_jsonl_from_line(input_file_path, 0)
    input_data = [extract_prompt_info(json_str) for json_str in input_data]
    input_df = pd.DataFrame(input_data)
    start_line = num_lines = len(input_df) // 9

    return input_df, start_line, num_lines

def read_and_process_plain_text_responses(output_file_path, num_lines):
    """Reads the plain text responses from the given output file path and processes them."""
    outputs_plain = read_jsonl(output_file_path, num_lines)
    outputs_plain_ids = pd.DataFrame([output["custom_id"] for output in outputs_plain], columns=["custom_id"])

    outputs_tokens = [output["response"]["body"]["usage"] for output in outputs_plain]
    outputs_input_tokens = [output["prompt_tokens"] for output in outputs_tokens]
    outputs_output_tokens = [output["completion_tokens"] for output in outputs_tokens]
    usage_data = pd.DataFrame(list(zip(outputs_input_tokens, outputs_output_tokens)), columns=["input_tokens", "output_tokens"])

    outputs_plain = [output["response"]["body"]["choices"][0]["message"]["content"] for output in outputs_plain]
    outputs_plain = [item.split(', ') for item in outputs_plain]

    outputs_plain = [item if len(item) <= 4 else [None] for item in outputs_plain]
    outputs_plain = [item + [None] * (4 - len(item)) for item in outputs_plain]
    output_cols = ['headline type', 'confidence', 'magnitude', 'explanation']

    outputs_plain_df = pd.DataFrame(outputs_plain, columns=output_cols)
    outputs_plain_df = pd.concat([outputs_plain_ids, outputs_plain_df], axis=1)

    outputs_plain_df = pd.concat([outputs_plain_df, usage_data], axis=1)

    return outputs_plain_df

def read_and_process_json_responses(output_file_path, start_line):
    """Reads the JSON responses from the given output file path and processes them."""
    outputs_json = read_jsonl_from_line(output_file_path, start_line)
    outputs_json_ids = pd.DataFrame([output["custom_id"] for output in outputs_json], columns=["custom_id"])

    outputs_tokens = [output["response"]["body"]["usage"] for output in outputs_json]
    outputs_input_tokens = [output["prompt_tokens"] for output in outputs_tokens]
    outputs_output_tokens = [output["completion_tokens"] for output in outputs_tokens]
    usage_data = pd.DataFrame(list(zip(outputs_input_tokens, outputs_output_tokens)), columns=["input_tokens", "output_tokens"])

    outputs_json = [output["response"]["body"]["choices"][0]["message"]["content"] for output in outputs_json]
    outputs_json = [extract_json(json_str) for json_str in outputs_json]
    outputs_json = [output if output is not None else {"headline type": None} for output in outputs_json]

    output_cols = ['headline type', 'confidence', 'magnitude', 'explanation']
    outputs_json = [{key: d.get(key, None) for key in output_cols} for d in outputs_json]
    outputs_json_df = pd.DataFrame(outputs_json, columns=output_cols)
    outputs_json_df = pd.concat([outputs_json_ids, outputs_json_df], axis=1)

    outputs_json_df = pd.concat([outputs_json_df, usage_data], axis=1)
    return outputs_json_df

def combine_responses(outputs_plain_df, outputs_json_df):
    """Combines the given plain and JSON outputs into a single DataFrame."""
    combined_output = pd.concat([outputs_plain_df, outputs_json_df], ignore_index=True)
    return combined_output

def merge_input_with_combined_output(input_df, combined_output):
    """Merge the input dataframe with the combined output dataframe based on the 'custom_id' column."""
    data = pd.merge(input_df, combined_output, on='custom_id', how='left')
    data['headline type'] = data['headline type'].str.lower()
    data['explanation'] = data['explanation'].str.lower()
    return data

def clean_and_filter_data(data, question):
    """Cleans and filters the given data based on the specified question."""
    valid_headlines = ['positive', 'neutral', 'negative'] if question == "1" else ['increase', 'uncertain', 'decrease']
    data.loc[~data['headline type'].isin(valid_headlines), 'headline type'] = None
    
    data['headline type num'] = data['headline type'].map({'positive': 2, 'neutral': 1, 'negative': 0}) if question == "1" else data['headline type'].map({'increase': 2, 'uncertain': 1, 'decrease': 0})
    data['confidence'] = pd.to_numeric(data['confidence'], errors='coerce')
    data['magnitude'] = pd.to_numeric(data['magnitude'], errors='coerce')
   
    data.loc[~data['confidence'].between(0, 1), 'confidence'] = None
    data.loc[~data['magnitude'].between(0, 1), 'magnitude'] = None
    return data

def process(question, model, month, year):
    input_file_path, output_file_path = construct_file_paths(question, model, month, year)
    input_df, start_line, num_lines = read_and_process_input_data(input_file_path)
    outputs_plain_df = read_and_process_plain_text_responses(output_file_path, num_lines)
    outputs_json_df = read_and_process_json_responses(output_file_path, start_line)
    combined_output = combine_responses(outputs_plain_df, outputs_json_df)
    data = merge_input_with_combined_output(input_df, combined_output)
    data = clean_and_filter_data(data, question)
    return data

def calculate_statistics(data):
    """Calculate statistics for the given data."""
    data_mean = data.groupby('headline').agg({
        'confidence': ['mean', 'std', 'nunique'],
        'magnitude': ['mean', 'std', 'nunique'],
        'headline type num': ['mean', 'std', 'nunique']
    }).reset_index()

    data_mean.columns = ['_'.join(col).strip() for col in data_mean.columns.values]
    return data_mean

def main(question, model, month, year):
    if month == "oct":
        data_first = process(question, model, f"{month}first", year)
        data_second = process(question, model, f"{month}second", year)
        data = pd.concat([data_first, data_second], ignore_index=True)
    else:    
        data = process(question, model, month, year)
    
    # Ensure the directory exists and save the CSV file
    output_dir = f"{step4_path}/{model}/q{question}"
    os.makedirs(output_dir, exist_ok=True)
    data.to_csv(f"{output_dir}/q{question}_{month}{year}_processed.csv", index=False)

if __name__ == "__main__":
    
    QUESTION = economic_questions
    MODEL = models
    MONTH =  month_batches
    YEARS = years

    for question in QUESTION:
        for model in MODEL:
            for month in MONTH:
                for year in YEARS:
                    main(question=question, model=model, month=month, year=year)
                    print(f"Cleaned responses for {question}, {model}, {month}, {year}")