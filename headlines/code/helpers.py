import pandas as pd

def get_missing_headlines(path1: str, path2: str) -> pd.Series:
    """ Get the headlines in the first CSV that aren't in the second CSV.

    Args:
        path1 (str): The file path to the first CSV.
        path2 (str): The file path to the second CSV.

    Returns:
        pd.Series: The headlines in the first CSV that aren't in the second CSV.
    """
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
    