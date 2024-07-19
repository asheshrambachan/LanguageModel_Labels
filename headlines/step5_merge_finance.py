import pandas as pd

# Read in data
labels = pd.read_csv("./dec19_output.csv")
headlines = pd.read_csv("./dec19.csv")

base_blanks = pd.merge(labels[labels['prompt_type'] == 1], headlines, on=['headline', 'company_name'])
base_json = pd.merge(labels[labels['prompt_type'] == 0], headlines, on=['headline', 'company_name'])

persona1 = pd.merge(labels[labels['prompt_type'] == 2], headlines, on=['headline', 'company_name'])
persona2 = pd.merge(labels[labels['prompt_type'] == 3], headlines, on=['headline', 'company_name'])
persona3 = pd.merge(labels[labels['prompt_type'] == 4], headlines, on=['headline', 'company_name'])
persona4 = pd.merge(labels[labels['prompt_type'] == 5], headlines, on=['headline', 'company_name'])

cot1 = pd.merge(labels[labels['prompt_type'] == 6], headlines, on=['headline', 'company_name'])
cot2 = pd.merge(labels[labels['prompt_type'] == 7], headlines, on=['headline', 'company_name'])
cot3 = pd.merge(labels[labels['prompt_type'] == 8], headlines, on=['headline', 'company_name'])

base_blanks.to_csv("base_blanks.csv", index=False)
base_json.to_csv("base_json.csv", index=False)
persona1.to_csv("persona1.csv", index=False)
persona2.to_csv("persona2.csv", index=False)
persona3.to_csv("persona3.csv", index=False)
persona4.to_csv("persona4.csv", index=False)
cot1.to_csv("cot1.csv", index=False)
cot2.to_csv("cot2.csv", index=False)
cot3.to_csv("cot3.csv", index=False)


