# Function to randomly sample an index from step4 where "headline type" is None
import pandas as pd
import random
import json
import os
from constants import step2_path, step4_path, step7_path, step8_path

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
 

def main():
    batch_summary_file = pd.read_csv(step7_path + "/batch_metrics.csv") 
    bad_responses = []
    
    # Filter rows where any model's "empty headlines" column is greater than 5
    filtered_rows = batch_summary_file[batch_summary_file["empty headlines"] > 5]
    
    # Now iterate over only the filtered rows
    for index, row in filtered_rows.iterrows():
        empty_col = "empty headlines"
        if row[empty_col] > 5:
            # Get the corresponding file from step4
            month = row['month']
            model = row["model"]
            question = str(row['question'])
            prompt_type = row['file']
            step4_file = os.path.join(step4_path, model, "q" + question, f"q{question}_{month}19_processed.csv")
            
            # Sample an index where "headline type" is None in step4
            sampled_index = sample_index_from_step4(step4_file)
            if sampled_index is not None:
                if month == "oct":
                    # Get the corresponding file from step2
                    step2_file1 = os.path.join(step2_path, model, "q" + question, f"q{question}_{month}first19_responses.jsonl")
                    step2_file2 = os.path.join(step2_path, model, "q" + question, f"q{question}_{month}second19_responses.jsonl")
                    bad_response1 = read_line_from_step2(step2_file1, sampled_index)
                    bad_response2 = read_line_from_step2(step2_file2, sampled_index)
                    bad_responses.append({
                        "custom id": sampled_index,
                        "model": model,
                        "month": month,
                        "prompt type": prompt_type,
                        "question": question,
                        "bad_response": bad_response1,
                    })
                    bad_responses.append({
                        "custom id": sampled_index,
                        "model": model,
                        "month": month,
                        "prompt type": prompt_type,
                        "question": question,
                        "bad_response": bad_response2
                    })
                else:    
                    # Get the corresponding file from step2
                    step2_file = os.path.join(step2_path, model, "q" + question, f"q{question}_{month}19_responses.jsonl")
                    # Read and collect the line from step2 using the sampled index
                    bad_response = read_line_from_step2(step2_file, sampled_index)
                    bad_responses.append({
                        "custom id": sampled_index,
                        "model": model,
                        "month": month,
                        "prompt type": prompt_type,
                        "question": question,
                        "bad_response": bad_response
                    })
                    
    bad_responses  = pd.DataFrame(bad_responses)
    os.makedirs(step8_path, exist_ok=True)
    bad_responses.to_csv(step8_path + "/bad_responses.csv", index=False)

if __name__ == "__main__":
    bad_responses = main()
    