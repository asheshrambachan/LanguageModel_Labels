import os
import pandas as pd
import numpy as np
from constants import step5_path, step6_path
from constants import models, month_batches, prompt_types, return_types, economic_questions

# Function to calculate cumulative abnormal returns (CAR)
def calculate_CAR(df):
    df["sum_exret_1"] = df[["exret", "exret_1"]].apply(lambda x: x.sum() if not x.isna().any() else float('nan'), axis=1)
    df["sum_exret_5"] = df[["sum_exret_1", "exret_2", "exret_3", "exret_4", "exret_5"]].apply(lambda x: x.sum() if not x.isna().any() else float('nan'), axis=1)
    df["sum_exret_10"] = df[["sum_exret_5", "exret_6", "exret_7", "exret_8", "exret_9", "exret_10"]].apply(lambda x: x.sum() if not x.isna().any() else float('nan'), axis=1)
    return df.drop(columns=[col for col in df.columns if col.startswith("exret_")])

# Function to read, combine, mutate, and filter data for all files
def read_combine_filter(model, months, question, file_name, return_type):
    combined_df = pd.concat([pd.read_csv(f"{step5_path}/{return_type}/{model}/q{question}/q{question}_{month}19/{file_name}", low_memory=False) 
                             for month in months], ignore_index=True)

    # Replace empty strings and other placeholders with NaN
    combined_df.replace("", np.nan, inplace=True)
    
    # Apply filtering
    if return_type == "realized":
        filtered_df = combined_df.dropna(subset=["ret_fd1", "ret_fd5", "ret_fd10", "ret_ld1", "ret_ld2", "ret_ld3", "headline type", "confidence", "magnitude"])
    else:
        combined_df = calculate_CAR(combined_df)
        filtered_df = combined_df.dropna(subset=["sum_exret_1", "sum_exret_5", "sum_exret_10", "confidence", "magnitude", "headline type"])

    return filtered_df

# Function to deduplicate records (take the average magnitude and confidence if multiple)
def deduplicate_records(df):
    # Determine the most common 'headline type' using mode, handle numeric variables with mean
    deduplicated = (
        df.groupby('headline', as_index=False)
        .agg({
            'headline type': lambda x: pd.Series.mode(x).iloc[0] if not pd.Series.mode(x).empty else np.nan,
            'magnitude': 'mean',
            'confidence': 'mean',
            **{col: 'first' for col in df.columns if col not in ['headline type', 'magnitude', 'confidence']}
        })
    )
    return deduplicated

def save_common_sample_within(question, model, return_type):
    filtered_data = {file_name: read_combine_filter(model=model, 
                                                    months=month_batches,
                                                    file_name=f"{file_name}.csv",
                                                    question=question, 
                                                    return_type=return_type) 
                    for file_name in prompt_types}

    common_headlines = set.intersection(*[set(df["headline"]) for df in filtered_data.values()])

    final_data = {
        file_name: deduplicate_records(df[df["headline"].isin(common_headlines)]) 
        for file_name, df in filtered_data.items()
    }

    # Save the cleaned datasets
    for file_name, final_df in final_data.items():
        os.makedirs(f"{step6_path}/within_model/{return_type}/{model}/q{question}", exist_ok=True)
        save_path = f"{step6_path}/within_model/{return_type}/{model}/q{question}/{file_name}.csv"
        final_df.to_csv(save_path, index=False)

    print(f"Saved common sample within model for {question}, {model}, and {return_type}")

 
def save_common_sample_across(question, return_type):

    # Step 1: Read, combine, and filter data for all models
    filtered_data_across_models = {
        model: {
            file_name: pd.read_csv(f"{step6_path}/within_model/{return_type}/{model}/q{question}/{file_name}.csv", low_memory=False)
            for file_name in prompt_types
        }
        for model in models
    }

    # Step 2: Find the common headlines across all datasets and all models
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
            os.makedirs(f"{step6_path}/across_models/{return_type}/{model}/q{question}", exist_ok=True)
            save_path = f"{step6_path}/across_models/{return_type}/{model}/q{question}/{file_name}.csv"
            file_df.to_csv(save_path, index=False)    

        print(f"Saved common sample across model for {question}, {model}, and {return_type}")
  
    
if __name__ == "__main__":
    for return_type in return_types:
        for question in economic_questions:
            for model in models:
                save_common_sample_within(question, model, return_type)
            
            save_common_sample_across(question, return_type)

