import json
import pandas as pd
import re
from s0_constants import personas, thought_modifiers

def read_jsonl(file_path, num_lines):
    """Reads a specified number of lines from a JSONL file."""
    with open(file_path, 'r') as file:
        return [json.loads(line.strip()) for i, line in enumerate(file) if i < num_lines]

def read_jsonl_from_line(file_path, start_line):
    """Reads a JSONL file starting from a specified line."""
    with open(file_path, 'r') as file:
        return [json.loads(line.strip()) for i, line in enumerate(file) if i >= start_line]

def extract_json(json_str):
    """Extracts the JSON object from the given JSON string and trims anything after the 'explanation' field
    only if there is an error in parsing.
    Args:
        json_str (str): The JSON string.
    Returns:
        dict: The extracted JSON object.
    """
    match = re.search(r'\{.*\}', json_str, re.DOTALL)
    if match:
        json_text = match.group(0)

        try:
            # Try to load the JSON as-is first
            return json.loads(json_text)  
        except json.JSONDecodeError:
            # If parsing fails, attempt to cut off the "explanation" field and re-parse
            explanation_index = json_text.find('"explanation"')
            if explanation_index != -1:
                # Cut off everything two characters before "explanation", remove trailing comma and newline
                json_text = json_text[:explanation_index - 2].rstrip(', \n') + "}"
            try:
                return json.loads(json_text)  
            except json.JSONDecodeError:
                print(f"Offending JSON string: {repr(json_text)}")
                return None
    return None

def extract_prompt_info(json_str):
    """Extracts the prompt information from the given JSON string.
    Args:
        json_str (str): The JSON string.
    Returns:
        dict: The extracted prompt information.
        """
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

def construct_file_paths(question, model, month, year):
    """Constructs the input and output file paths based on the given parameters.
    Args:
        question (str): The question type.
        model (str): The model name.
        month (str): The month.
        year (str): The year.
    Returns:
        tuple: The input and output file paths.
    """

    input_file_path = f'./data/step1_batch_prompts/{model}/q{question}/q{question}_{month}{year}_prompts.jsonl'
    output_file_path = f'./data/step2_batch_responses/{model}/q{question}/q{question}_{month}{year}_responses.jsonl'
    return input_file_path, output_file_path

def read_and_process_input_data(input_file_path):
    """Reads the input data from the given input file path and processes it.
    Args:
        input_file_path (str): The input file path.
    Returns:
        pandas.DataFrame: The processed input data.
    """

    input_data = read_jsonl_from_line(input_file_path, 0)
    input_data = [extract_prompt_info(json_str) for json_str in input_data]
    input_df = pd.DataFrame(input_data)
    start_line = num_lines = len(input_df) // 9
    return input_df, start_line, num_lines

def read_and_process_plain_text_responses(output_file_path, num_lines):
    """Reads the plain text responses from the given output file path and processes them.
    Args:
        output_file_path (str): The output file path.
        num_lines (int): The number of lines to read from the output file.
    Returns:
        pandas.DataFrame: The processed plain text responses
    """

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
    """Reads the JSON responses from the given output file path and processes them.
    Args:
        output_file_path (str): The output file path.
        start_line (int): The start line to read the JSON responses from.
    Returns:
        pandas.DataFrame: The processed JSON responses.
    """

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
    """Combines the given plain and JSON outputs into a single DataFrame.
    Args:
        outputs_plain_df (pandas.DataFrame): The DataFrame containing the plain outputs.
        outputs_json_df (pandas.DataFrame): The DataFrame containing the JSON outputs.
    Returns:
        pandas.DataFrame: The combined DataFrame containing both plain and JSON outputs.
    """

    combined_output = pd.concat([outputs_plain_df, outputs_json_df], ignore_index=True)
    return combined_output

def merge_input_with_combined_output(input_df, combined_output):
    """Merge the input dataframe with the combined output dataframe based on the 'custom_id' column.
    Args:
        input_df (pandas.DataFrame): The input dataframe.
        combined_output (pandas.DataFrame): The combined output dataframe.
    Returns:
        pandas.DataFrame: The merged dataframe with the 'headline type' and 'explanation' columns converted to lowercase.
    """

    data = pd.merge(input_df, combined_output, on='custom_id', how='left')
    data['headline type'] = data['headline type'].str.lower()
    data['explanation'] = data['explanation'].str.lower()
    return data

def clean_and_filter_data(data, question):
    """Cleans and filters the given data based on the specified question.
    Args:
        data (pandas.DataFrame): The input data to be cleaned and filtered.
        question (str): The question type. Should be "1" for sentiment analysis or any other value for magnitude analysis.
    Returns:
        pandas.DataFrame: The cleaned and filtered data.
    """

    valid_headlines = ['positive', 'neutral', 'negative'] if question == "1" else ['increase', 'uncertain', 'decrease']
    data.loc[~data['headline type'].isin(valid_headlines), 'headline type'] = None
    data['headline type num'] = data['headline type'].map({'positive': 2, 'neutral': 1, 'negative': 0}) if question == "1" else data['headline type'].map({'increase': 2, 'uncertain': 1, 'decrease': 0})
    data['confidence'] = pd.to_numeric(data['confidence'], errors='coerce')
    data['magnitude'] = pd.to_numeric(data['magnitude'], errors='coerce')
    data.loc[~data['confidence'].between(0, 1), 'confidence'] = None
    data.loc[~data['magnitude'].between(0, 1), 'magnitude'] = None
    return data


def calculate_statistics(data):
    """Calculate statistics for the given data.
    Parameters:
    - data: pandas DataFrame
        The input data for which statistics need to be calculated.
    Returns:
    - data_mean: pandas DataFrame
        The calculated statistics grouped by 'headline'
    """

    # Group by 'headline' and calculate statistics
    data_mean = data.groupby('headline').agg({
        'confidence': ['mean', 'std', 'nunique'],
        'magnitude': ['mean', 'std', 'nunique'],
        'headline type num': ['mean', 'std', 'nunique']
    }).reset_index()

    # Flatten MultiIndex columns
    data_mean.columns = ['_'.join(col).strip() for col in data_mean.columns.values]
    return data_mean

def main(question, model, month, year):

    input_file_path, output_file_path = construct_file_paths(question, model, month, year)
    input_df, start_line, num_lines = read_and_process_input_data(input_file_path)
    outputs_plain_df = read_and_process_plain_text_responses(output_file_path, num_lines)
    outputs_json_df = read_and_process_json_responses(output_file_path, start_line)
    combined_output = combine_responses(outputs_plain_df, outputs_json_df)
    if len(input_df) != len(combined_output):
        print(f"Length mismatch: input_df: {len(input_df)}, combined_output: {len(combined_output)}")
        print(question, model, month)
    data = merge_input_with_combined_output(input_df, combined_output)
    data = clean_and_filter_data(data, question)

    # Save the processed data to a CSV file
    data.to_csv(f"./data/step4_processed_responses/{model}/q{question}/q{question}_{month}{year}_processed.csv", index=False)

if __name__ == "__main__":
    
    QUESTION = ["3"]
    MODEL = ["gpt-4o"]
    MONTH = ["aug"]
    YEAR = "19"

    for question in QUESTION:
        for model in MODEL:
            for month in MONTH:
                main(question=question, model=model, month=month, year=YEAR)