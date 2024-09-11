import os
import pandas as pd

# Directory where your models are stored
root_dir = "./data/step1_batch_prompts"  

# Initialize an empty list to store the counts
file_data = []

# Traverse the directory structure
for model_dir in os.listdir(root_dir):
    model_path = os.path.join(root_dir, model_dir)
    
    # Check if it's a directory (each model is a directory)
    if os.path.isdir(model_path):
        # Recursively walk through each model directory
        for dirpath, dirnames, filenames in os.walk(model_path):
            for file in filenames:
                if file.endswith('.jsonl'):
                    file_path = os.path.join(dirpath, file)

                    # Select characters in the file after the first 3 characters and before the last 7 characters
                    month = file[3:-16]

                    # Count the number of lines (rows) in the JSONL file
                    with open(file_path, 'r', encoding='utf-8') as f:
                        row_count = sum(1 for _ in f)

                    # Append the data to the list
                    file_data.append({
                        'Model': model_dir,
                        'Month': month,
                        'Question': dirpath[-2:],
                        'Row Count': row_count
                    })

# Create a DataFrame from the file data
df = pd.DataFrame(file_data)

# Optionally save the DataFrame to a CSV file
df.to_csv('prompt_counts_batch.csv', index=False)
