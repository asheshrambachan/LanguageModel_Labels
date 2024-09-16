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
        row_count, empty_count, dup_count = 0, 0, 0

    prompt_row_count = count_jsonl_rows(prompt_file_path) / 9 if os.path.exists(prompt_file_path) else 0
    
    return {
        f"{model_dir} response rows": row_count,
        f"{model_dir} prompt rows": prompt_row_count,
        f"{model_dir} empty headlines": empty_count,
        f"{model_dir} duplicate headlines": dup_count
    }

# Function to calculate deduplicated and clean rows
def calculate_deduplicated_clean(df, model):
    df[f"{model} deduplicated"] = df[f"{model} response rows"] - df[f"{model} duplicate headlines"]
    df[f"{model} clean"] = df[f"{model} deduplicated"] - df[f"{model} empty headlines"]

# Function to add grouped sum columns
def add_grouped_sum(df, column_prefix):
    grouped = df.groupby(["return type", "file", "question"])[[f"{model} {column_prefix}" for model in models]].transform('sum')
    for model in models:
        df[f"{model} {column_prefix} sum"] = grouped[f"{model} {column_prefix}"]

# Main function to execute the core logic
def main():
    summary_data = []
    
    # Main loop through directories and files
    for return_type in return_types[0:1]:
        for question_dir in economic_questions:
            for month_dir in month_batches:
                for file in prompt_types:
                    model_data = {}
                    for model_dir in models:
                        response_file_path = os.path.join(root_dir_responses, return_type, model_dir, question_dir, f"{question_dir}_{month_dir}19", file, ".csv")
                        prompt_file_path = os.path.join(root_dir_prompts, model_dir, question_dir, f"{question_dir}_{month_dir}19_prompts.jsonl")
                        model_data.update(get_model_data(model_dir, response_file_path, prompt_file_path))
                    
                    # Append summary data for this file
                    summary_data.append({
                        "return type": return_type,
                        "question": question_dir,
                        "month": month_dir,
                        "file": file,
                        **model_data
                    })

    # Convert summary data to DataFrame
    summary_df = pd.DataFrame(summary_data)

    # Apply deduplicated and clean row calculations to all models
    for model in models:
        calculate_deduplicated_clean(summary_df, model)

    # Check if deduplicated rows are equal across models
    summary_df["deduplicated equal for all models?"] = (
        (summary_df["gpt-3.5-turbo deduplicated"] == summary_df["gpt-4o deduplicated"]) &
        (summary_df["gpt-3.5-turbo deduplicated"] == summary_df["gpt-4o-mini deduplicated"])
    )

    # Sum deduplicated and clean rows
    add_grouped_sum(summary_df, "deduplicated")
    add_grouped_sum(summary_df, "clean")

    # Get minimum clean rows across models
    min_clean_rows = summary_df.groupby(["return type", "question"])[[f"{model} clean" for model in models]].min().reset_index()

    # Rename columns for clarity
    min_clean_rows.rename(columns={
        "gpt-3.5-turbo clean": "gpt-3.5-turbo common sample",
        "gpt-4o clean": "min gpt-4o common sample",
        "gpt-4o-mini clean": "min gpt-4o-mini common sample"
    }, inplace=True)

    # Merge minimum clean rows back into summary_df
    summary_df = summary_df.merge(min_clean_rows, on=["return type", "question"], how="left")

    # Save the updated summary_df to CSV
    summary_df.to_csv("response_counts_batch.csv", index=False)

# Run the main function when the script is executed
if __name__ == "__main__":
    main()
