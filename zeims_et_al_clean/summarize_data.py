import pandas as pd

from css_mappings import DATASETS

def main():
    for dataset in DATASETS:

        # Load the data from a CSV file
        data = pd.read_csv(dataset + ".csv")

        # Group the data by 'labels' and 'LLM_correct', and count the occurrences
        summary_table = data.groupby(['LLM_correct', 'labels']).size().unstack(fill_value=0)

        # Print the summary table
        print(summary_table, "\n")

if __name__ == "__main__":
    main()

