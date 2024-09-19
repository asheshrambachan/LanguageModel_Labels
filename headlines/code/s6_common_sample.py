import os
import pandas as pd
import numpy as np
from s0_constants import economic_questions, models, month_batches, return_types, prompt_types

# Function to calculate cumulative abnormal returns (CAR)
def calculate_CAR(df):
    df["sum_exret_1"] = df["exret"] + df["exret_1"]
    df["sum_exret_5"] = df["sum_exret_1"] + df[["exret_2", "exret_3", "exret_4", "exret_5"]].sum(axis=1)
    df["sum_exret_10"] = df["sum_exret_5"] + df[["exret_6", "exret_7", "exret_8", "exret_9", "exret_10"]].sum(axis=1)
    return df.drop(columns=[col for col in df.columns if col.startswith("exret_")])

# Function to read, combine, mutate, and filter data for all files
def read_combine_filter(model, months, question, file_name, return_type):
    combined_df = pd.concat([pd.read_csv(f"./data/step5_merged_returns/{return_type}/{model}/q{question}/q{question}_{month}19/{file_name}") 
                             for month in months])

    if return_type == "cumulative":
        combined_df = combined_df.dropna(subset=["ret_fd1", "ret_fd5", "ret_fd10", "ret_ld1", "ret_ld2", "ret_ld3", "headline type", "confidence", "magnitude"])
    else:
        combined_df = calculate_CAR(combined_df)
        combined_df = combined_df.dropna(subset=["sum_exret_1", "sum_exret_5", "sum_exret_10", "headline type", "confidence", "magnitude"])
        
    return combined_df

# Function to deduplicate records based on common headlines
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
    
    # Step 2: Find the common headlines across all datasets using set intersection
    common_headlines = set.intersection(*[set(df["headline"]) for df in filtered_data.values()])
    
    # Step 3: Filter and deduplicate records based on common headlines
    final_data = {
        file_name: deduplicate_records(df[df["headline"].isin(common_headlines)]) 
        for file_name, df in filtered_data.items()
    }

    # Save the cleaned datasets
    for file_name, final_df in final_data.items():
        save_path = f"./data/step6_common_sample/within_model/{return_type}/{model}/q{question}/{file_name}.csv"
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        final_df.to_csv(save_path, index=False)

def save_common_sample_across(question, return_type):

    # Step 1: Read, combine, and filter data for all models
    filtered_data_across_models = {
        model: {
            file_name: read_combine_filter(model=model, 
                                           months=month_batches,
                                           file_name=f"{file_name}.csv",
                                           question=question, 
                                           return_type=return_type) 
            for file_name in prompt_types
        }
        for model in models
    }

    # Step 2: Find the common headlines across all datasets and all models
    # Ensure we are working with DataFrames and Series explicitly
    common_headlines_across_models = set.intersection(
        *[
            set.intersection(*[
                set(pd.DataFrame(df)["headline"])  # Explicitly convert df to DataFrame to avoid ndarray issue
                for df in model_data.values()
            ])
            for model_data in filtered_data_across_models.values()
        ]
    )

    # Step 3: Filter and deduplicate records based on common headlines across models
    final_data_across_models = {
        model: {
            file_name: deduplicate_records(pd.DataFrame(df)[df["headline"].isin(common_headlines_across_models)]) 
            for file_name, df in model_data.items()
        }
        for model, model_data in filtered_data_across_models.items()
    }

    # Step 4: Save the cleaned datasets for each model
    for model, final_data in final_data_across_models.items():
        for file_name, final_df in final_data.items():
            save_path = f"./data/step6_common_sample/across_models/{return_type}/{model}/q{question}/{file_name}.csv"
            os.makedirs(os.path.dirname(save_path), exist_ok=True)
            final_df.to_csv(save_path, index=False)


def main(question, model, return_type):
    save_common_sample_within(question, model, return_type)

if __name__ == "__main__":

    for return_type in return_types:
        for question in economic_questions:
            for model in models:
                main(question, model, return_type)      

