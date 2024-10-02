import os
import pandas as pd
from constants import (
    return_types, month_batches, years, economic_questions, models, 
    prompt_types, step1_path, step5_path, step6_path, step7_path
)
from helpers import get_batch_file_metrics, count_overlap, count_jsonl_rows

# Function to get model data
def get_batch_info(response_file_path, prompt_file_path):
    row_count, empty_count, dup_count = (0, 0, 0)
    prompt_row_count = 0

    if os.path.exists(response_file_path):
        row_count, empty_count, dup_count = get_batch_file_metrics(response_file_path)

    if os.path.exists(prompt_file_path):
        prompt_row_count = count_jsonl_rows(prompt_file_path) / 9
    elif "oct" in prompt_file_path:
        first = prompt_file_path[:-16] + "first" + prompt_file_path[-16:]
        second = prompt_file_path[:-16] + "second" + prompt_file_path[-16:]
        if os.path.exists(first) and os.path.exists(second):
            prompt_row_count = count_jsonl_rows(first) / 9 + count_jsonl_rows(second) / 9

    return {
        "response rows": row_count,
        "prompt rows": prompt_row_count,
        "empty headlines": empty_count,
        "duplicate headlines": dup_count
    }

def get_combined_info(response_file_path, model_common_file_path, all_common_file_path):
    model_sample_count = count_overlap(response_file_path, model_common_file_path) if os.path.exists(model_common_file_path) else 0
    model_sample_count1 = count_overlap(model_common_file_path, response_file_path) if os.path.exists(model_common_file_path) else 0
    all_sample_count = count_overlap(response_file_path, all_common_file_path) if os.path.exists(all_common_file_path) else 0
    all_sample_count1 = count_overlap(all_common_file_path, response_file_path) if os.path.exists(all_common_file_path) else 0

    return {
        "rows in model sample": model_sample_count,
        "rows in all sample": all_sample_count,
        "model sample rows in batch": model_sample_count1,
        "all sample rows in batch": all_sample_count1
    }

# Main function to execute the core logic
def main(questions, models, months, return_types, prompt_types):
    monthly_batch_info = []
    
    for question_dir, model_dir, return_type, file, month_dir in [(q, m, rt, p, mn) 
        for q in questions for m in models for rt in return_types for p in prompt_types for mn in months]:
        
        print(f"Processing: q{question_dir}, {model_dir}, {return_type}, {file}, {month_dir}")

        model_common_file_path = os.path.join(step6_path, "within_model", return_type, model_dir, f"q{question_dir}", f"{file}.csv")
        all_common_file_path = os.path.join(step6_path, "across_models", return_type, model_dir, f"q{question_dir}", f"{file}.csv")
        response_file_path = os.path.join(step5_path, return_type, model_dir, f"q{question_dir}", f"q{question_dir}_{month_dir}19", f"{file}.csv")
        prompt_file_path = os.path.join(step1_path, model_dir, f"q{question_dir}", f"q{question_dir}_{month_dir}19_prompts.jsonl")

        model_data = get_batch_info(response_file_path, prompt_file_path)
        combined_info = get_combined_info(response_file_path, model_common_file_path, all_common_file_path)

        monthly_batch_info.append({
            "question": question_dir,
            "month": month_dir,
            "model": model_dir,
            "file": file,
            "return_type": return_type,
            **model_data,
            **combined_info
        })

    # Convert summary data to DataFrame and save
    os.makedirs(step7_path, exist_ok=True)
    pd.DataFrame(monthly_batch_info).to_csv(step7_path + "/batch_metrics.csv", index=False)

# Run the main function when the script is executed
if __name__ == "__main__":
    main(economic_questions, models, month_batches, return_types, prompt_types)
