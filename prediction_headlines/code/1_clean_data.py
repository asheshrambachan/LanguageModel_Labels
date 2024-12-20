import os
import pandas as pd
import string
import re


# Define directories
REPO_DIR = '.'
DATA_DIR = os.path.join(REPO_DIR, 'prediction_headlines/data')
TEMP_DIR = os.path.join(REPO_DIR, 'prediction_headlines/temp')
RETURNS_DATA_DIR = os.path.join(REPO_DIR, 'headlines/data/step0_returns_data/realized')
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)


def clean_text(x):    
    # remove punctuation, lowercase, and remove tailing spaces
    x = re.sub('[{}]'.format(string.punctuation), '', x)
    x = re.sub(r'[^a-zA-Z0-9]', ' ', x.lower()).strip()
    return x

def main():
    # Create an empty list to store individual DataFrames
    dfs = []

    # Loop through all files in the directory
    for file in os.listdir(RETURNS_DATA_DIR):
        # Check if the file is a CSV
        if file.endswith(".csv"):
            file_path = os.path.join(RETURNS_DATA_DIR, file)
            df = pd.read_csv(file_path)
            dfs.append(df)

    # Concatenate all DataFrames into one
    headlines = pd.concat(dfs, ignore_index=True)

    # Drop columns
    headlines = headlines[['date', 'headline', 'company_name']]
    
    # Remove duplicates based on headline (lower cased)
    headlines['headline_clean'] = headlines['headline'].apply(lambda x: clean_text(x))
    headlines.drop_duplicates(subset='headline_clean', inplace=True)
    print(f'Removed duplicate headlines, n = {len(headlines)}.')
    headlines.drop(columns="headline_clean", inplace=True)

    # Add id column
    headlines.reset_index(inplace=True, drop=True)
    headlines['headline_id'] = headlines.index
    
    headlines['headline'] = headlines['headline'].str.replace('"', r'', regex=False) #.str.replace('\'', r'', regex=False)

    headlines_path = os.path.join(TEMP_DIR, f"headlines_{len(headlines)}.csv")
    headlines.to_csv(headlines_path, index=False)
    print(f'Saved {os.path.basename(headlines_path)}, n = {len(headlines)}, at {os.path.dirname(headlines_path)}')

    # Draw 10K sample 
    headlines = headlines.sample(n=10_000, random_state=123)

    # Save 10K sample
    headlines_path = os.path.join(DATA_DIR, 'headlines.csv')
    headlines.to_csv(headlines_path, index=False)
    print(f'Saved {os.path.basename(headlines_path)}, n = {len(headlines)}, at {os.path.dirname(headlines_path)}')

if __name__ == "__main__":
    main()