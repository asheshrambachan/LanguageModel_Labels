from matplotlib import pyplot as plt
import pandas as pd
import os
import seaborn as sns

from css_mappings import DATASETS, MODELS

# make sure we're working in the code directory
script_path = os.path.abspath(__file__)
script_directory = os.path.dirname(script_path)
os.chdir(script_directory)

def main():
    for dataset in DATASETS:
        
        # Load the data from a CSV file
        data = pd.read_csv("../data/" + dataset + ".csv")
        label_columns = []

        for model in MODELS:
        
            try:
                # Group the data by 'labels' and 'LLM_correct', and count the occurrences
                label_column = model + '_correct'
                summary_table = data.groupby([label_column, 'labels']).size().unstack(fill_value=0)
                label_columns.append(label_column)

            except:
                summary_table = f"{model} labels do not exist for {dataset}"

            # Print the summary table
            print(summary_table, "\n")
        
        # save correlation matrix for labels
        labels = data[label_columns]
        plt.figure(figsize=(10, 8))
        sns.heatmap(labels.corr(), annot=True, cmap='coolwarm', vmin=-1, vmax=1)
        plt.title('LLM Labels Correlation Matrix')
        plt.savefig(f'../figures/correlation_matrices/{dataset}.png', bbox_inches='tight')

if __name__ == "__main__":
    main()

