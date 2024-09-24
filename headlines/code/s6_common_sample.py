import os
import pandas as pd
import numpy as np
from constants import models, month_batches, prompt_types, step5_path, step6_path

# Function to calculate cumulative abnormal returns (CAR)
def calculate_CAR(df):
    df["sum_exret_1"] = df["exret"] + df["exret_1"]
    df["sum_exret_5"] = df["sum_exret_1"] + df[["exret_2", "exret_3", "exret_4", "exret_5"]].sum(axis=1)
    df["sum_exret_10"] = df["sum_exret_5"] + df[["exret_6", "exret_7", "exret_8", "exret_9", "exret_10"]].sum(axis=1)
    return df.drop(columns=[col for col in df.columns if col.startswith("exret_")])

# Function to read, combine, mutate, and filter data for all files
def read_combine_filter(model, months, question, file_name, return_type):
    combined_df = pd.concat([pd.read_csv(f"{step5_path}/{return_type}/{model}/q{question}/q{question}_{month}19/{file_name}") 
                             for month in months])

    if return_type == "realized":
        combined_df = combined_df.dropna(subset=["ret_fd1", "ret_fd5", "ret_fd10", "ret_ld1", "ret_ld2", "ret_ld3", "headline type", "confidence", "magnitude"])
    else:
        combined_df = calculate_CAR(combined_df)
        combined_df = combined_df.dropna(subset=["sum_exret_1", "sum_exret_5", "sum_exret_10", "headline type", "confidence", "magnitude"])
        
    return combined_df

# Function to deduplicate records (take the average magnitude and confidence if multiple)
def deduplicate_records(df):
    # Group by headline and handle character and numeric variables
    deduplicated = df.groupby("headline", as_index=False).agg({
        'headline type': lambda x: x.mode()[0] if len(x.mode()) > 0 else np.nan,
        'magnitude': 'mean',
        'confidence': 'mean',
        **{col: 'first' for col in df.columns if col not in ['headline type', 'magnitude', 'confidence']}
    })
    return deduplicated

def save_common_sample_within(question, model, return_type):

    # Step 1: Read, combine, and filter data for all files
    filtered_data = {file_name: read_combine_filter(model=model, 
                                                    months=month_batches,
                                                    file_name=f"{file_name}.csv",
                                                    question=question, 
                                                    return_type=return_type) 
                    for file_name in prompt_types}
    
    print("Step 1 - valid respopnses by prompting strategy: ", [len(df) for df in filtered_data.values()])

    # Step 2: Find and filter the common headlines across all datasets using set intersection
    common_headlines = set.intersection(*[set(df["headline"]) for df in filtered_data.values()])
    final_data = {
        file_name: deduplicate_records(df[df["headline"].isin(common_headlines)]) 
        for file_name, df in filtered_data.items()
    }
    print("Step 2 - common headlines: ", len(common_headlines))

    # Save the cleaned datasets
    for file_name, final_df in final_data.items():
        save_path = f"{step6_path}/within_model/{return_type}/{model}/q{question}/{file_name}.csv"
        final_df.to_csv(save_path, index=False)
    print("Step 3 - saved files")

def save_common_sample_across(question, return_type):

    # Step 1: Read, combine, and filter data for all models
    filtered_data_across_models = {
        model: {
            file_name: pd.read_csv(f"{step6_path}/within_model/{return_type}/{model}/q{question}/{file_name}.csv")
            for file_name in prompt_types
        }
        for model in models
    }

    # Step 2: Find the common headlines across all datasets and all models
    # Ensure we are working with DataFrames and Series explicitly
    common_headlines_across_models = set.intersection(
        *[
            set.intersection(*[
                set(df["headline"])
                for df in model_data.values()
            ])
            for model_data in filtered_data_across_models.values()
        ]
    )

    # Step 3: Filter records based on common headlines across models
    final_data_across_models = {
        model: {
            file_name: pd.DataFrame(df)[df["headline"].isin(common_headlines_across_models)] 
            for file_name, df in model_data.items()
        }
        for model, model_data in filtered_data_across_models.items()
    }

    # Step 4: Save the cleaned datasets for each model
    for model, model_data in final_data_across_models.items():
        for file_name, file_df in model_data.items():
            save_path = f"{step6_path}/across_models/{return_type}/{model}/q{question}/{file_name}.csv"
            file_df.to_csv(save_path, index=False)

def main(question, model, return_type):
    save_common_sample_within(question, model, return_type)

if __name__ == "__main__":

    RETURN_TYPES = ["abnormal_CAPM", "abnormal_FF3", "realized"]
    QUESTIONS = ["1", "2", "3", "4", "5"]
    MODELS = ["gpt-4o-mini", "gpt-3.5-turbo", "gpt-4o"]

    for return_type in RETURN_TYPES:
        for question in QUESTIONS:
            for model in MODELS:
                print(f"Processing {model} for question {question} and return type {return_type}")
                main(question, model, return_type)      

