import pandas as pd
import os

MONTH = "octsecond"
QUESTION = "5"

# Read in data
labels = pd.read_csv("./" + MONTH + "19/" + "q" + QUESTION + "_processed.csv")
headlines = pd.read_csv("./" + MONTH + "19.csv").drop_duplicates(subset=['headline', 'company_name'])

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

directory = "./" + MONTH + "19/q" + QUESTION
os.makedirs(directory, exist_ok=True)

base_blanks.to_csv(directory + "/base_blanks.csv", index=False)
base_json.to_csv(directory + "/base_json.csv", index=False)
persona1.to_csv(directory + "/persona1.csv", index=False)
persona2.to_csv(directory + "/persona2.csv", index=False)
persona3.to_csv(directory+ "/persona3.csv", index=False)
persona4.to_csv(directory + "/persona4.csv", index=False)
cot1.to_csv(directory + "/cot1.csv", index=False)
cot2.to_csv(directory + "/cot2.csv", index=False)
cot3.to_csv(directory + "/cot3.csv", index=False)



