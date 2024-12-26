import os
import pandas as pd
import numpy as np
from copy import deepcopy

# Define directories
REPO_DIR = '.'
DATA_DIR = os.path.join(REPO_DIR, 'estimation_legislation/data')
temp_dir = os.path.join(REPO_DIR, 'estimation_legislation/temp')
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(temp_dir, exist_ok=True)

MAJOR_CODE = pd.read_csv(os.path.join(DATA_DIR, "major_topics.csv")).set_index('Major')['MajorText'].to_dict()

def get_cap(path_cap):
    # Load CAP data from path
    cap = pd.read_csv(path_cap, low_memory=False)

    # Correct BillID
    cap['BillID'] = cap['cong'].astype(str) + '-' + cap['bill_type'].apply(lambda x: x.upper()) + '-' + cap['bill_no'].astype(str) 

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
        'name_full': 'NameFull'
        }, inplace=True)

    # Remove duplicates based on bill ID
    cap.drop_duplicates(subset='BillID', inplace=True)

    # Correct chamber encoding for the 114th congress
    if ~((cap.loc[cap['Cong']==114, 'Chamber'].unique()) == [1,2]).all():
        cap.loc[cap['Cong']==114, 'Chamber'] = cap.loc[cap['Cong']==114, 'Chamber'] + 1
    cap['Chamber'] = cap['Chamber'].apply(lambda x: int(x == 2)) # House = 1, Senate = 2 in CAP

    # Recode Party 400 as Democratic (100) 
    cap.loc[(cap['Party']==400) & (cap['NameFull']=='Anibal Acevedo-Vila'), 'Party'] = 100

    # Keep columns we need
    cap = cap[['BillID', 'Major', 'Description', 'Party', 'Chamber', 'Year', 'PassH', 'PassS']]

    # Drop bills with missing data
    cap.dropna(inplace=True)

    # Make Major, PassH and PassS integers
    cap['Major'] = cap['Major'].apply(lambda x: int(x))
    cap['PassH'] = cap['PassH'].apply(lambda x: int(x))
    cap['PassS'] = cap['PassS'].apply(lambda x: int(x))

    # # Correct Description
    # cap['Description'] = cap['Description'].str.replace(r'[_]|[?"]{2,}|[`]|[\']', '', regex=True)
    # cap['Description'] = cap['Description'].str.replace(r'\s+', ' ', regex=True)
    return(cap)

def get_cbp(path_cbp_80_92, path_cbp_93_114):
    # Load CBP data, 80th through 92nd congress
    cbp_80_92 = pd.read_csv(path_cbp_80_92, sep='\t', encoding='latin-1', low_memory=False)
    cbp_80_92.rename(columns={' ': 'Minor'}, inplace=True)
    cbp_80_92['DW1'] = cbp_80_92['DW1'].apply(lambda x: np.nan if x == -99.0 else x)

    # Load CBP data, 93rd through 114th congress
    cbp_93_114 = pd.read_csv(path_cbp_93_114, sep=';', encoding='latin-1', low_memory=False)
    cbp_93_114['DW1'] = cbp_93_114['DW1'].apply(lambda s: float(s.replace(',', '.') if isinstance(s, str) else s))

    # Merge CBP datasets
    cbp = pd.concat([cbp_80_92, cbp_93_114], join='inner').reset_index(drop=True)

    # Rename columns
    cbp.rename(columns={'Title': 'Description'}, inplace=True)

    # Correct BillID
    cbp['BillType'] = cbp['BillType'].apply(lambda x: x.upper())
    cbp['BillID'] = cbp['Cong'].astype(str) + '-' + cbp['BillType'] + '-' + cbp['BillNum'].astype(str) 

    # Remove duplicates in CBP based on BillID, keeping the bill with Major code similar to that in CAP
    condition = (
        ((cbp['BillID']=="107-HR-5715") & (cbp['Major']!=12)) |
        ((cbp['BillID']=="107-S-3051") & (cbp['Major']!=9)) |
        ((cbp['BillID']=="107-S-3160") & (cbp['Major']!=15))
    ) # These are bills with Major_CBP != Major_CAP
    cbp = cbp[~condition]
    cbp.drop_duplicates(subset=['BillID'], inplace=True)
     
    # Impute missing DW1 scores
    cbp['DW1_NA'] = cbp['DW1']
    dw1 = cbp.groupby(['NameFull', 'DW1'], group_keys=True).first()['DW1_NA'] 
    dw1_mean = dw1.mean()
    cbp.fillna(value={'DW1': dw1_mean}, inplace=True)

    # Keep columns we need
    cbp = cbp[['BillID', 'Major', 'Description', 'Party', 'Chamber', 'DW1', 'PassH', 'PassS', 'Postal', 'IntrDate']]

    # Drop bills with missing data
    cbp.dropna(inplace=True, subset=['BillID', 'Major', 'Description', 'Party', 'Chamber', 'DW1', 'PassH', 'PassS', 'Postal'])

    # Make Majors an integer
    cbp['Major'] = cbp['Major'].apply(lambda x: int(x))

    # Correct date data:
    # First try parsing as MM/DD/YYYY
    intr_date = cbp['IntrDate']
    cbp['IntrDate'] = pd.to_datetime(intr_date, format='%m/%d/%Y', errors='coerce')

    # For rows where this failed (NaT), try parsing as YYYY-MM-DD
    cbp['IntrDate'] = cbp['IntrDate'].fillna(pd.to_datetime(intr_date, format='%Y-%m-%d', errors='coerce'))

    # # Correct Description
    # cbp['Description'] = cbp['Description'].str.replace(r'[_]|[?"]{2,}|[`]|[\']', '', regex=True)
    # cbp['Description'] = cbp['Description'].str.replace(r'\s+', ' ', regex=True)
    return(cbp)

# Merge CAP and CBP datasets ------------------------------------------------------
def description_mismatch(d1, d2):
    description_cap = pd.Series(deepcopy(d1))
    description_cbp = pd.Series(deepcopy(d2))
    
    description_cbp = description_cbp.apply(lambda x: x.lower())
    description_cap = description_cap.apply(lambda x: x.lower())

    description_cbp = description_cbp.str.replace('??????', '')
    description_cbp = description_cbp.str.replace('???', '')
    description_cbp = description_cbp.str.replace('""""', '')
    description_cbp = description_cbp.str.replace('`', '')
    description_cbp = description_cbp.str.replace("'s", "s") 

    description_cap = description_cap.str.replace('_??', '')
    description_cap = description_cap.str.replace('""""', '')
    description_cap = description_cap.str.replace('`', '')
    description_cap = description_cap.str.replace("'s", "s") 

    condition = description_cap!=description_cbp
    description_cbp[condition] = description_cbp[condition].str.replace('\' ', ' ')
    description_cbp[condition] = description_cbp[condition].str.replace(' \'', ' ')
    description_cap[condition] = description_cap[condition].str.replace('\' ', ' ')
    description_cap[condition] = description_cap[condition] .str.replace(' \'', ' ')
    description_cap[condition] = description_cap[condition].str.replace("'", "")
    
    condition = description_cap!=description_cbp
    return condition

def merge_cap_cbp(cap, cbp):
    # Merge CAP and CBP
    bills = cap.merge(cbp, on=['BillID', 'Major', 'Party', 'PassS', 'PassH', 'Chamber'], suffixes=('', '_CBP'))

    # Drop bills with mismatching Description in CAP and CBP
    condition = description_mismatch(bills['Description'], bills['Description_CBP'])
    bills = bills[~condition] 

    # Remove bills with Major=99 (~80,000)
    bills = bills[bills['Major']!=99]

    # Remove duplicates based on Description (lower cased)
    bills['Description_lower'] = bills['Description'].apply(lambda x: x.lower())
    bills.drop_duplicates(subset='Description_lower', inplace=True)
    
    # Map PAP/CAP major topic IDs to our IDs 
    major_PAP2Ours = {
        1:  1,
        2:  2,
        3:  3,
        4:  4,
        5:  5,
        6:  6,
        7:  7,
        8:  8,
        9:  9,
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
    bills['Major'] = bills['Major'].apply(lambda x: major_PAP2Ours[x])
    bills['MajorText'] = bills['Major'].apply(lambda x: MAJOR_CODE[x])

    # Add Chamber codes
    chamber_code = {
        0: 'House', 
        1: 'Senate'
    }
    bills['Chamber'] = bills['Chamber'].apply(lambda x: chamber_code[x])

    # Add Party codes
    party_code = {
        100: 'Democrat', 
        112: 'Conservative',
        200: 'Republican',
        328: 'Independent'
    }
    bills['Party'] = bills['Party'].apply(lambda x: party_code[x])

    # Rearrange columns
    bills = bills[['BillID', 'Year', 'Major', 'MajorText', 'Party', 'PassH', 'PassS', 'Description', 'DW1', 'Chamber', 'Postal', 'IntrDate']]
    bills.reset_index(drop=True)
    return(bills)

def sample_bills(bills, n_bills = 10e3, n_examples = 15, seed = 123):
    # Bills used for few-shot prompting
    examples = bills.groupby('Major').sample(n=1, random_state=seed).reset_index(drop=True)[:n_examples] 

    condition = bills['BillID'].apply(lambda x: x not in examples['BillID'].to_list())
    bills = bills[condition]
    print(f'Removed {len(examples)} examples from bills data.')
    bills_10k_estimation = bills.sample(n=int(n_bills), random_state=seed)

    return(bills_10k_estimation, examples)

def main():
    # CAP and CBP data paths
    path_cap = 'https://comparativeagendas.s3.amazonaws.com/datasetfiles/US-Legislative-congressional_bills_19.3_3_3.csv' 
    path_cbp_80_92 = 'http://congressionalbills.org/billfiles/bills80-92.zip' 
    path_cbp_93_114 = 'http://congressionalbills.org/billfiles/bills93-114.zip' 
    # path_cap = os.path.join(temp_dir, 'US-Legislative-congressional_bills_19.3_3_3.csv')
    # path_cbp_80_92 = os.path.join(temp_dir, 'bills80-92.txt')
    # path_cbp_93_114 = os.path.join(temp_dir, 'bills93-114.csv')
    
    # Load and clean CAP
    cap = get_cap(path_cap)
    # cap.to_csv(os.path.join(temp_dir, "cap.csv"), index=False)
    # print(f'Saved cap.csv, n = {len(cap)}, at {temp_dir}')

    # Load and clean CBP
    cbp = get_cbp(path_cbp_80_92, path_cbp_93_114)
    # cbp.to_csv(os.path.join(temp_dir, "cbp.csv"), index=False)
    # print(f'Saved cbp.csv, n = {len(cbp)}, at {temp_dir}')

    # Merge CAP and CBP data
    bills = merge_cap_cbp(cap, cbp)
    bills.to_csv(os.path.join(temp_dir, "bills_228387.csv"), index=False)
    print(f'Saved bills_228387.csv, n = {len(bills)}, at {temp_dir}') # n = 228,387

    # Draw 10k bills and 5*3=15 bill examples used for few-shot prompts.
    bills_estimation, bills_examples = sample_bills(bills, n_bills=10e3, n_examples = 15)

    # Split the 15 examples into 3 sets for the 3 few-shot prompts
    bills_examples['ExampleSetNum'] = np.repeat([1, 2, 3], repeats=15/3)
    bills_examples_path = os.path.join(DATA_DIR, 'bills_examples.csv')
    bills_examples.to_csv(bills_examples_path, index=False)
    print(f'Saved {os.path.basename(bills_examples_path)}, n = {len(bills_examples)}, at {os.path.dirname(bills_examples_path)}')

    # Save 10K bills data for the estimation exercise 
    bills_estimation_path = os.path.join(DATA_DIR, 'bills.csv')
    bills_estimation.to_csv(bills_estimation_path, index=False)
    print(f'Saved {os.path.basename(bills_estimation_path)}, n = {len(bills_estimation)}, at {os.path.dirname(bills_estimation_path)}')

if __name__ == "__main__":
    main()