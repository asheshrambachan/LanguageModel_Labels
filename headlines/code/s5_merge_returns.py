import pandas as pd
from constants import economic_questions, models, month_batches, return_types, years, returns_path, step4_path, step5_path
import os

def read_data(question, model, month, year, return_type):
    labels = pd.read_csv(f"{step4_path}/{model}/q{question}/q{question}_{month}{year}_processed.csv")
    headlines = pd.read_csv(f"{returns_path}/{return_type}/{month}{year}_{return_type}.csv").drop_duplicates(subset=['headline', 'company_name'])
    return labels, headlines

def merge_data(labels, headlines):
    base_blanks = pd.merge(labels[labels['prompt_type'] == 1], headlines, on=['headline', 'company_name'], how="left")
    base_json = pd.merge(labels[labels['prompt_type'] == 0], headlines, on=['headline', 'company_name'], how="left")

    persona1 = pd.merge(labels[labels['prompt_type'] == 2], headlines, on=['headline', 'company_name'], how="left")
    persona2 = pd.merge(labels[labels['prompt_type'] == 3], headlines, on=['headline', 'company_name'], how="left")
    persona3 = pd.merge(labels[labels['prompt_type'] == 4], headlines, on=['headline', 'company_name'], how="left")
    persona4 = pd.merge(labels[labels['prompt_type'] == 5], headlines, on=['headline', 'company_name'], how="left")

    cot1 = pd.merge(labels[labels['prompt_type'] == 6], headlines, on=['headline', 'company_name'], how="left")
    cot2 = pd.merge(labels[labels['prompt_type'] == 7], headlines, on=['headline', 'company_name'], how="left")
    cot3 = pd.merge(labels[labels['prompt_type'] == 8], headlines, on=['headline', 'company_name'], how="left")

    unique_headlines_base_blanks = base_blanks[~base_blanks['headline'].isin(base_json['headline'])]

    return {
        "base_blanks": base_blanks,
        "base_json": base_json,
        "persona1": persona1,
        "persona2": persona2,
        "persona3": persona3,
        "persona4": persona4,
        "cot1": cot1,
        "cot2": cot2,
        "cot3": cot3,
        "unique_headlines_base_blanks": unique_headlines_base_blanks
    }

def save_data(data, directory):
    os.makedirs(directory, exist_ok=True)
    data["base_blanks"].to_csv(f"{directory}/base_blanks.csv", index=False)
    data["base_json"].to_csv(f"{directory}/base_json.csv", index=False)
    data["persona1"].to_csv(f"{directory}/persona1.csv", index=False)
    data["persona2"].to_csv(f"{directory}/persona2.csv", index=False)
    data["persona3"].to_csv(f"{directory}/persona3.csv", index=False)
    data["persona4"].to_csv(f"{directory}/persona4.csv", index=False)
    data["cot1"].to_csv(f"{directory}/cot1.csv", index=False)
    data["cot2"].to_csv(f"{directory}/cot2.csv", index=False)
    data["cot3"].to_csv(f"{directory}/cot3.csv", index=False)

def main(question, model, month, year, return_type):
    labels, headlines = read_data(question, model, month, year, return_type)
    merged_data = merge_data(labels, headlines)
    directory = f"{step5_path}/{return_type}/{model}/q{question}/q{question}_{month}{year}"
    save_data(merged_data, directory)

if __name__ == "__main__":

    QUESTIONS = ["1", "2", "3", "4", "5"]
    MODELS = ["gpt-3.5-turbo", "gpt-4o", "gpt-4o-mini"]
    MONTHS = ["oct"]
    YEARS = ["19"]
    RETURN_TYPES = ["realized", "abnormal_CAPM", "abnormal_FF3"]

    for question in QUESTIONS:
        for model in MODELS:
            for month in MONTHS:
                for year in YEARS:
                    for return_type in RETURN_TYPES:
                        main(question=question, 
                             model=model, 
                             month=month, 
                             year=year, 
                             return_type=return_type)