import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from copy import deepcopy

# Define directories
repo_dir = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills_v2"
os.chdir(repo_dir)

data_dir = os.path.join(repo_dir, "Data")
os.makedirs(data_dir, exist_ok=True)

fig_dir = os.path.join(repo_dir, "Figures and Tables")
os.makedirs(fig_dir, exist_ok=True)

# path_cap = "https://comparativeagendas.s3.amazonaws.com/datasetfiles/US-Legislative-congressional_bills_19.3_3_3.csv"
# path_cbp_80_92 = "http://congressionalbills.org/billfiles/bills80-92.zip"
# path_cbp_93_114 = "http://congressionalbills.org/billfiles/bills93-114.zip"
path_cap = os.path.join(data_dir, "CAP.csv")
path_cbp_80_92 = os.path.join(data_dir, "CBP80-92.txt")
path_cbp_93_114 = os.path.join(data_dir, "CBP93-114.csv")

MAJOR_PAP2OURS = {
    1 : 1 ,
    2 : 2 ,
    3 : 3 ,
    4 : 4 ,
    5 : 5 ,
    6 : 6 ,
    7 : 7 ,
    8 : 8 ,
    9 : 9 ,
    10: 10,
    12: 11,
    13: 12,
    14: 13,
    15: 14,
    16: 15,
    17: 16,
    18: 17,
    19: 18,
    20: 19,
    21: 20
}

MAJOR_TEXT = pd.read_csv(os.path.join(data_dir, "Codebooks/major_topics.csv")).set_index('Major')['MajorText'].to_dict()

CHAMBER_CODE = {
    0: "House", 
    1: "Senate"
    }

PARTY_CODE = {
    100: "Democrat", 
    112: "Conservative",
    200: "Republican",
    328: "Independent"
}

# Clean CAP data ------------------------------------------------------
# Load CAP data
cap = pd.read_csv(path_cap, low_memory=False)

# Correct BillID
cap["BillID"] = cap["cong"].astype(str) + "-" + cap["bill_type"].apply(lambda x: x.upper()) + "-" + cap["bill_no"].astype(str) 

# Rename columns for consistency
cap.rename(columns={
    'majortopic': 'Major',
    'description': 'Description',
    'year': 'Year',
    'party': 'Party', 
    'pass_h': 'PassH', 
    'pass_s': 'PassS',
    'chamber': 'Chamber',
    'cong': 'Cong',
    'name_full': 'NameFull'}, inplace=True)

# Drop bills with missing data
cap.dropna(inplace=True, subset=['BillID', 'Year', 'Major', 'Description', 'Party', 'PassH', 'PassS', 'Chamber'])

# Remove duplicates based on bill ID
cap.drop_duplicates(subset=["BillID"], inplace=True)

# Remove bills with Major=99 (~80,000)
cap = cap[cap["Major"]!=99]

# Correct chamber encoding for the 114th congress
if ~((cap.loc[cap["Cong"]==114,"Chamber"].unique()) == [1,2]).all():
    cap.loc[cap["Cong"]==114,"Chamber"] = cap.loc[cap["Cong"]==114,"Chamber"] + 1
cap["Chamber"] = cap["Chamber"].apply(lambda x: int(x == 2)) # House = 1, Senate = 2 in CAP

# Recode Party 400 as Democratic (100) 
cap.loc[(cap["Party"]==400) & (cap["NameFull"]=="Anibal Acevedo-Vila"), "Party"] = 100

# Make Major, PassH and PassS integers
cap['Major']  = cap['Major'].apply(lambda x: int(x))
cap['PassH']  = cap['PassH'].apply(lambda x: int(x))
cap['PassS']  = cap['PassS'].apply(lambda x: int(x))

# Keep columns we use
cap = cap[['BillID', 'Year', 'Major', 'Description', 'Party', 'PassH', 'PassS', 'Chamber']]

# Clean CBP data ------------------------------------------------------
# Load CBP data, 80th through 92nd congress
cbp_80_92 = pd.read_csv(path_cbp_80_92, sep='\t', encoding='latin-1', low_memory=False)
cbp_80_92.rename(columns={' ': 'Minor'}, inplace=True)
cbp_80_92.drop(columns=['id', 'ByReq', 'Commem', 'oldMajor', 'oldMinor', 'Month', 'ReferArr', 'Year', 'Age', 'ComMArr', 'DW2', 'LeadCham', 'LeadComm', 'LeadSubC'], inplace=True)
cbp_80_92["DW1"] = cbp_80_92["DW1"].apply(lambda x: np.nan if x == -99.0 else x)

# Load CBP data, 93rd through 114th congress
cbp_93_114 = pd.read_csv(path_cbp_93_114, sep=';', encoding='latin-1', low_memory=False)
cbp_93_114.drop(columns='ImpBill', inplace=True)
cbp_93_114["DW1"] = cbp_93_114["DW1"].apply(lambda s: float(s.replace(",", ".") if isinstance(s, str) else s))

# Combine CBP datasets
cbp = pd.concat([cbp_80_92, cbp_93_114]).reset_index()
cbp.drop(columns='index', inplace=True)

# Correct BillID
cbp["BillType"] = cbp["BillType"].apply(lambda x: x.upper())
cbp["BillID"] = cbp["Cong"].astype(str) + "-" + cbp["BillType"] + "-" + cbp["BillNum"].astype(str) 

# Rename columns
cbp.rename(columns={'Title': 'Description'}, inplace=True)

# Drop bills with missing data
cbp.dropna(inplace=True, subset=['BillID', 'Major', 'Description', 'Party', 'PassH', 'PassS', 'Chamber'])

# Impute missing DW1 scores
cbp["DW1_NA"] = cbp["DW1"]
dw1 = cbp.groupby(["NameFull","DW1"], group_keys=True).first()["DW1_NA"] 
dw1_mean = dw1.mean()
cbp.fillna(value={"DW1": dw1_mean}, inplace=True)

# Select columns
cbp = cbp[['BillID', 'Major', 'Description', 'Party', 'PassH', 'PassS', 'Chamber', 'DW1_NA', 'DW1', 'Postal']]

# Make Majors an integer
cbp['Major'] = cbp['Major'].apply(lambda x: int(x))

# Merge CAP and CBP datasets ------------------------------------------------------
def description_mismatch(d1, d2):
    description_cap = pd.Series(deepcopy(d1))
    description_cbp = pd.Series(deepcopy(d2))
    
    description_cbp = description_cbp.apply(lambda x: x.lower())
    description_cap = description_cap.apply(lambda x: x.lower())
    description_cbp = description_cbp.str.replace('??????', '')
    description_cbp = description_cbp.str.replace('???', '')
    description_cbp = description_cbp.str.replace('""""', '')
    description_cap = description_cap.str.replace('_??', '')
    description_cap = description_cap.str.replace('""""', '')
    description_cbp = description_cbp.str.replace('`', '')
    description_cbp = description_cbp.str.replace("'s", "s") 
    description_cap = description_cap.str.replace('`', '')
    description_cap = description_cap.str.replace("'s", "s") 

    condition = description_cap!=description_cbp
    description_cbp[condition] = description_cbp[condition].str.replace('\' ', ' ')
    description_cbp[condition] = description_cbp[condition].str.replace(' \'', ' ')
    description_cap[condition] = description_cap[condition].str.replace('\' ', ' ')
    description_cap[condition] = description_cap[condition] .str.replace(' \'', ' ')
    description_cap[condition] = description_cap[condition].str.replace("'", "")

    condition = (description_cap!=description_cbp) & (description_cap.apply(lambda x: x[:6]=="A bill")) & (description_cbp.apply(lambda x: x[:6]=="An Act"))
    description_cbp[condition] = description_cbp[condition].str.replace("An Act", "A bill", n=1) # around 1000 of those are different in how they start: "A bill" vs "An Act"

    condition = description_cap!=description_cbp
    return condition

bills = cap.merge(cbp, on=["BillID", "Major", "Party", "PassS", "PassH", "Chamber"], suffixes=("", "_CBP"))

# Drop bills with mismatching Description in CAP and CBP
condition = description_mismatch(bills["Description"], bills["Description_CBP"])
bills = bills[~condition] 

# Remove duplicates based on Description (lower cased)
bills["Description_lower"] = bills["Description"].apply(lambda x: x.lower())
bills.drop_duplicates(subset="Description_lower", inplace=True)

# Map PAP/CAP major topic IDs to our IDs 
bills["Major"] = bills["Major"].apply(lambda x: MAJOR_PAP2OURS[x])

# Add MajorText column 
bills["MajorText"] = bills["Major"].apply(lambda x: MAJOR_TEXT[x])

# Add Chamber codes
bills["Chamber"] = bills["Chamber"].apply(lambda x: CHAMBER_CODE[x])

# Add Party codes
bills["Party"] = bills["Party"].apply(lambda x: PARTY_CODE[x])

# Rearrange columns
bills = bills[['BillID', 'Year', 'Major', 'MajorText', 'Party', 'PassH', 'PassS', 'Description', 'DW1', 'DW1_NA', 'Chamber', 'Postal']]
bills.reset_index(inplace=True)
print(len(bills))
seed = 123
n_examples = 5
# Bills used for few-shot prompting
examples = bills.groupby("Major").sample(n=1, random_state=seed).reset_index(drop=True)[:(n_examples*3)] # replace is False by default
examples["ExampleSetNum"] = np.repeat([1, 2, 3], repeats=n_examples)
examples.to_csv(os.path.join(data_dir, "bills_examples.csv"), index=False)
print(f"Saved bills_examples.csv, n = {len(examples)}, at {data_dir}")

# examples01 = examples.iloc[:n_examples]
# examples02 = examples.iloc[n_examples:(n_examples*2)]
# examples03 = examples.iloc[(n_examples*2):]
# examples01.to_csv(os.path.join(data_dir, "bills_example1.csv"), index=False)
# examples02.to_csv(os.path.join(data_dir, "bills_example2.csv"), index=False)
# examples03.to_csv(os.path.join(data_dir, "bills_example3.csv"), index=False)

condition = bills["BillID"].apply(lambda x: x not in examples["BillID"].to_list())
bills = bills[condition]
print(f"Removed {len(examples)} examples from bills data.")

bills_10k = bills.sample(n=10_000, random_state=seed)
bills_10k.to_csv(os.path.join(data_dir, "bills_10k.csv"), index=False)
print(f"Saved bills_10k.csv, n = {len(bills_10k)}, at {data_dir}")

plt.figure(figsize=(10, 6))
bills_10k['Year'].hist(bins=range(int(bills_10k['Year'].min()), int(bills_10k['Year'].max()) + 1, 2), edgecolor='black')
plt.title('A histogram of the frequency of the 10K bills over years')
plt.xlabel('Year')
plt.ylabel('Number of Bills')
plt.grid(False)
plt.savefig(os.path.join(fig_dir, 'A histogram of the frequency of the 10K bills over years.png'))
print(f"Saved figures at {fig_dir}")