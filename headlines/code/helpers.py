import pandas as pd
import json
import os
import random
from s0_constants import models

# Function to compare two CSV files and return the missing headlines
def get_missing_headlines(path1: str, path2: str) -> pd.Series:
    # Load the two CSV files into DataFrames
    df1 = pd.read_csv(path1)
    df2 = pd.read_csv(path2)

    # Assuming the 'headline' column contains the headlines
    # Find the headlines in df1 that are not in df2
    unique_headlines = df1[~df1['headline'].isin(df2['headline'])]

    return unique_headlines['headline']

# Helper function to get file metrics for CSV files
def get_file_metrics(file_path):
    df = pd.read_csv(file_path)
    return len(df), df['headline type'].isna().sum(), df['headline'].duplicated().sum()

# Helper function to count rows in a .jsonl file
def count_jsonl_rows(file_path):
    with open(file_path, 'r') as f:
        return sum(1 for line in f)
    
# Function to check that the prompt types were properly merged
# If the rows/indeces get misaligned, we will see explanations in non-COT files
def check_merge_good(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            # Process only .csv files, skip everything else
            if not file.endswith('.csv'):
                continue

            if not file.startswith('cot'):
                file_path = os.path.join(root, file)
                try:
                    # Try reading the file and checking the "explanation" column
                    df = pd.read_csv(file_path)
                    if 'explanation' in df.columns and not df['explanation'].isna().all():
                        print(f"Explanation column is not empty in: {file_path}")
                except Exception as e:
                    print(f"Failed to process {file_path}: {e}")
    

# Function to randomly sample an index from step4 where "headline type" is None
def sample_index_from_step4(step4_file):
    try:
        step4_df = pd.read_csv(step4_file)
        null_headlines = step4_df[step4_df['headline type'].isna()].index.tolist()
        if not null_headlines:
            print(f"No empty 'headline type' found in {step4_file}")
            return None
        return random.choice(null_headlines)
    except Exception as e:
        print(f"Error reading {step4_file}: {e}")
        return None

# Function to read and print the corresponding line from step2 based on the sampled index
def read_line_from_step2(step2_file, line_number):
    try:
        with open(step2_file, 'r') as f:
            for i, line in enumerate(f):
                if i == line_number:
                    # print(f"Line from {step2_file} at index {line_number}:")  
                    return json.loads(line)['response']['body']['choices'][0]['message']['content']
                    break
    except Exception as e:
        print(f"Error reading {line_number} from {step2_file}: {e}")
        return None
 

def get_bad_sample(batch_summary_file):
    bad_responses = []
    
    # Filter rows where any model's "empty headlines" column is greater than 5
    filtered_rows = batch_summary_file[
        (batch_summary_file["gpt-3.5-turbo empty headlines"] > 5) |
        (batch_summary_file["gpt-4o empty headlines"] > 5) |
        (batch_summary_file["gpt-4o-mini empty headlines"] > 5)
    ]
    
    # Now iterate over only the filtered rows
    for index, row in filtered_rows.iterrows():
        for model in models:
            empty_col = f"{model} empty headlines"
            if row[empty_col] > 5:
                # Get the corresponding file from step4
                month = row['month']
                question = str(row['question'])
                step4_file = os.path.join('./data/step4_processed_responses', model, "q" + question, f"q{question}_{month}19_processed.csv")
                
                # Sample an index where "headline type" is None in step4
                sampled_index = sample_index_from_step4(step4_file)
                if sampled_index is not None:
                    # Get the corresponding file from step2
                    step2_file = os.path.join('./data/step2_batch_responses', model, "q" + question, f"q{question}_{month}19_responses.jsonl")
                    # Read and collect the line from step2 using the sampled index
                    bad_response = read_line_from_step2(step2_file, sampled_index)
                    bad_responses.append({
                        "custom id": sampled_index,
                        "model": model,
                        "month": month,
                        "question": question,
                        "bad_response": bad_response
                    })
                
    return pd.DataFrame(bad_responses)


df = pd.read_csv("response_counts_batch.csv")
bad_responses = get_bad_sample(df)
bad_responses.to_csv("bad_responses.csv", index=False)