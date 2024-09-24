import pandas as pd
import json
import os
import random
from constants import models

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
def get_batch_file_metrics(file_path):
    df = pd.read_csv(file_path)
    return len(df), df['headline type'].isna().sum(), df['headline'].duplicated().sum()

def count_overlap(df1path, df2path):
    df1 = pd.read_csv(df1path)
    df2 = pd.read_csv(df2path)
    return len(df1[df1['headline'].isin(df2['headline'])])

# Helper function to count rows in a .jsonl file
def count_jsonl_rows(file_path):
    with open(file_path, 'r') as f:
        return sum(1 for line in f)
    
# Convert stock returns to float
def try_float(s):
    try:
        if isinstance(s, str):
            return float(s[:-1])
        else:
            return float(s)
    except ValueError:
        return np.nan
    
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
    

def confirm_overwrite():
    """
    Prompts the user for confirmation before proceeding with an action
    that may overwrite existing data.
    
    Returns:
        bool: True if the user confirms to proceed, False otherwise.
    """
    confirmation = input("This will overwrite existing data. Do you want to proceed? (y/n): ").strip().lower()
    if confirmation in ['y', 'yes']:
        return True
    else:
        print("Operation aborted by user.")
        return False