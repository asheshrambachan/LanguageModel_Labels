import os
import pandas as pd
import string
import re

REPO_DIR = './headlines_prediction'

def clean_text(x):    
    # remove punctuation, lowercase, and remove tailing spaces
    x = re.sub('[{}]'.format(string.punctuation), '', x)
    x = re.sub(r'[^a-zA-Z0-9]', ' ', x.lower()).strip()
    return x

def main():
    # Define directories
    data_dir = os.path.join(REPO_DIR, 'Data')
    temp_dir = os.path.join(REPO_DIR, 'Temp')
    os.makedirs(data_dir, exist_ok=True)
    os.makedirs(temp_dir, exist_ok=True)

    # data paths
    returns_dir = os.path.join("./headlines/data/step0_returns_data/realized")
    
    # Create an empty list to store individual DataFrames
    dfs = []

    # Loop through all files in the directory
    for file in os.listdir(returns_dir):
        # Check if the file is a CSV
        if file.endswith(".csv"):
            file_path = os.path.join(returns_dir, file)
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

    # # Drop bills with missing date
    # headlines = headlines.dropna()
    # print(f'Removed headlines with missing date, n = {len(headlines)}.')

    # Add id column
    headlines.reset_index(inplace=True, drop=True)
    headlines['headline_id'] = headlines.index

    temp1 = headlines["headline"]
    headlines['headline'] = headlines['headline'].str.replace('"', r'', regex=False) #.str.replace('\'', r'', regex=False)
    print((temp1!=headlines['headline'] ).mean())

    headlines_path = os.path.join(data_dir, f"headlines_{len(headlines)}.csv")
    headlines.to_csv(headlines_path, index=False)
    print(f'Saved {os.path.basename(headlines_path)}, n = {len(headlines)}, at {os.path.dirname(headlines_path)}')

    # Draw 10K sample 
    headlines = headlines.sample(n=10_000, random_state=123)

    # Save 10K sample
    headlines_path = os.path.join(data_dir, 'headlines.csv')
    headlines.to_csv(headlines_path, index=False)
    print(f'Saved {os.path.basename(headlines_path)}, n = {len(headlines)}, at {os.path.dirname(headlines_path)}')

if __name__ == "__main__":
    main()