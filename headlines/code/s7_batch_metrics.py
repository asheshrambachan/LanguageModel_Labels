import os
import pandas as pd
from s0_constants import return_types, month_batches, years, economic_questions, models, prompt_types
from helpers import get_file_metrics, count_jsonl_rows

# Define directories
root_dir_responses = "./data/step5_merged_returns"
root_dir_prompts = "./data/step1_batch_prompts"

# Function to get model data
def get_model_data(model_dir, response_file_path, prompt_file_path):

    if os.path.exists(response_file_path):
        row_count, empty_count, dup_count = get_file_metrics(response_file_path)
    else:
        print(f"Response file for {model_dir} does not exist at {response_file_path}")
        row_count, empty_count, dup_count = 0, 0, 0

    if os.path.exists(prompt_file_path):
        prompt_row_count = count_jsonl_rows(prompt_file_path) / 9
    else:
        print(f"Prompt file for {model_dir} does not exist at {prompt_file_path}")
        prompt_row_count = 0

    return {
        f"{model_dir} response rows": row_count,
        f"{model_dir} prompt rows": prompt_row_count,
        f"{model_dir} empty headlines": empty_count,
        f"{model_dir} duplicate headlines": dup_count
    }

# Function to calculate deduplicated and clean rows
def calculate_deduplicated_clean(df, model):
    if f"{model} response rows" in df and f"{model} duplicate headlines" in df:
        df[f"{model} deduplicated"] = df[f"{model} response rows"] - df[f"{model} duplicate headlines"]
        df[f"{model} clean"] = df[f"{model} deduplicated"] - df[f"{model} empty headlines"]
        print(f"Calculated deduplicated/clean for {model}")
    else:
        print(f"Missing columns for {model}, skipping deduplicated/clean calculation.")

# Main function to execute the core logic
def main():
    summary_data = []
    return_type = "realized"
    
    # Main loop through directories and files
    for question_dir in economic_questions:  # Limiting question_dir to the first item for debugging
        for month_dir in month_batches:
            for file in prompt_types:
                model_data = {}
                for model_dir in models:
                    response_file_path = os.path.join(root_dir_responses, return_type, model_dir, "q" + question_dir, f"q{question_dir}_{month_dir}19", file + ".csv")
                    prompt_file_path = os.path.join(root_dir_prompts, model_dir, "q" + question_dir, f"q{question_dir}_{month_dir}19_prompts.jsonl")
                    
                    # Get data and print debug information
                    model_data.update(get_model_data(model_dir, response_file_path, prompt_file_path))
                
                # Append summary data for this file
                summary_data.append({
                    "question": question_dir,
                    "month": month_dir,
                    "file": file,
                    **model_data
                })

    # Convert summary data to DataFrame
    summary_df = pd.DataFrame(summary_data)

    # Check if DataFrame has been populated
    if summary_df.empty:
        print("No data found. Please check your file paths or input data.")
        return

    # Apply deduplicated and clean row calculations to all models
    for model in models:
        calculate_deduplicated_clean(summary_df, model)

    # Check if deduplicated columns were successfully created
    missing_cols = [col for col in ["gpt-3.5-turbo deduplicated", "gpt-4o deduplicated", "gpt-4o-mini deduplicated"] if col not in summary_df.columns]
    if missing_cols:
        print(f"Error: Missing columns: {missing_cols}")
        return

    # Check if deduplicated rows are equal across models
    summary_df["deduplicated equal for all models?"] = (
        (summary_df["gpt-3.5-turbo deduplicated"] == summary_df["gpt-4o deduplicated"]) &
        (summary_df["gpt-3.5-turbo deduplicated"] == summary_df["gpt-4o-mini deduplicated"])
    )

    # Save the updated summary_df to CSV
    summary_df.to_csv("./data/step7_batch_metrics.csv", index=False)

# Run the main function when the script is executed
if __name__ == "__main__":
    main()
