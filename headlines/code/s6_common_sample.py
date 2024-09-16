import pandas as pd
import numpy as np
from s0_constants import economic_questions, models, month_batches, return_types, prompt_types

# Function to calculate cumulative abnormal returns (CAR)
def calculate_CAR(df):
    df["sum_exret_1"] = df["exret"] + df["exret_1"]
    df["sum_exret_5"] = df["sum_exret_1"] + df[["exret_2", "exret_3", "exret_4", "exret_5"]].sum(axis=1)
    df["sum_exret_10"] = df["sum_exret_5"] + df[["exret_6", "exret_7", "exret_8", "exret_9", "exret_10"]].sum(axis=1)
    return df.drop(columns=df.filter(like="exret_").columns)

# Function to read, combine, mutate, and filter data for all files
def read_combine_filter(file_name, months, question, return_type):
    combined_df = pd.concat([pd.read_csv(f"../data/step5_merged_returns/{return_type}/{model}/{question}/{question}_{month}19/{file_name}") 
                             for month in months])

    if return_type == "cumulative":
        combined_df = combined_df.dropna(subset=["ret_fd1", "ret_fd5", "ret_fd10", "ret_ld1", "ret_ld2", "ret_ld3", "headline.type", "confidence", "magnitude"])
    else:
        combined_df = calculate_CAR(combined_df)
        combined_df = combined_df.dropna(subset=["sum_exret_1", "sum_exret_5", "sum_exret_10", "headline.type", "confidence", "magnitude"])
    
    return combined_df

# Function to deduplicate records based on common headlines
def deduplicate_records(df):
    # Group by headline and handle character and numeric variables
    deduplicated = df.groupby("headline").agg({
        'headline.type': lambda x: x.mode()[0] if len(x.mode()) > 0 else np.nan,
        'magnitude': 'mean',
        'confidence': 'mean',
        **{col: 'first' for col in df.columns if col not in ['headline.type', 'magnitude', 'confidence']}
    }).reset_index()
    return deduplicated

def save_common_sample(question, model, return_type):
    # Step 1: Read, combine, and filter data for all files
    filtered_data = {file_name: read_combine_filter(f"{file_name}.csv", month_batches, question, return_type) 
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
        save_path = f"../data/step6_common_sample/{return_type}/{model}/{question}/{file_name}.csv"
        final_df.to_csv(save_path, index=False)

def main(question, model, return_type):
    save_common_sample(question, model, return_type)  

if __name__ == "__main__":

    QUESTION = ["3"]
    MODEL = ["gpt-4o"]
    RETURN_TYPE = ["cumulative", "CAPM", "FF3"]

    for return_type in RETURN_TYPE:
        for question in QUESTION:
            for model in MODEL:
                main(question, model, return_type)      

