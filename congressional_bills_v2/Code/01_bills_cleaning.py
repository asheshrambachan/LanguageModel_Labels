import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from copy import deepcopy

REPO_DIR = '/Users/haya1/Documents/LanguageModel_Labels/congressional_bills_v2'

def load_cap(path_cap):
    cap = pd.read_csv(path_cap, low_memory=False)
    return(cap)

def clean_cap(cap):
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

    # Remove duplicates based on bill ID
    cap.drop_duplicates(subset='BillID', inplace=True)

    # Make Major, PassH and PassS integers
    cap['Major']  = cap['Major'].apply(lambda x: int(x))
    cap['PassH']  = cap['PassH'].apply(lambda x: int(x))
    cap['PassS']  = cap['PassS'].apply(lambda x: int(x))

    # # Correct Description
    # cap['Description'] = cap['Description'].str.replace(r'[_]|[?"]{2,}|[`]|[\']', '', regex=True)
    # cap['Description'] = cap['Description'].str.replace(r'\s+', ' ', regex=True)
    return(cap)

def load_cbp(path_cbp_80_92, path_cbp_93_114):  
    # Load CBP data, 80th through 92nd congress
    cbp_80_92 = pd.read_csv(path_cbp_80_92, sep='\t', encoding='latin-1', low_memory=False)
    cbp_80_92.rename(columns={' ': 'Minor'}, inplace=True)
    cbp_80_92['DW1'] = cbp_80_92['DW1'].apply(lambda x: np.nan if x == -99.0 else x)

    # Load CBP data, 93rd through 114th congress
    cbp_93_114 = pd.read_csv(path_cbp_93_114, sep=';', encoding='latin-1', low_memory=False)
    cbp_93_114['DW1'] = cbp_93_114['DW1'].apply(lambda s: float(s.replace(',', '.') if isinstance(s, str) else s))

    # Merge CBP datasets
    cbp = pd.concat([cbp_80_92, cbp_93_114], join='inner').reset_index(drop=True)
    return(cbp)

def clean_cbp(cbp):
    # Rename columns
    cbp.rename(columns={'Title': 'Description'}, inplace=True)

    # Correct BillID
    cbp['BillType'] = cbp['BillType'].apply(lambda x: x.upper())
    cbp['BillID'] = cbp['Cong'].astype(str) + '-' + cbp['BillType'] + '-' + cbp['BillNum'].astype(str) 

    # Remove duplicates in CBP based on BillID, keeping the bill with Major code similar to that in CAP
    cbp.drop_duplicates(subset=['BillID', 'Major'], inplace=True)
    condition = (
        ((cbp['BillID']=="107-HR-5715") & (cbp['Major']!=12)) |
        ((cbp['BillID']=="107-S-3051") & (cbp['Major']!=9)) |
        ((cbp['BillID']=="107-S-3160") & (cbp['Major']!=15))
    ) # These are bills with Major_CBP != Major_CAP
    cbp = cbp[~condition]
        
    # Impute missing DW1 scores
    cbp['DW1_NA'] = cbp['DW1']
    dw1 = cbp.groupby(['NameFull', 'DW1'], group_keys=True).first()['DW1_NA'] 
    dw1_mean = dw1.mean()
    # print(dw1_mean)
    cbp.fillna(value={'DW1': dw1_mean}, inplace=True)

    # Keep columns we need
    cbp = cbp[['BillID', 'Major', 'Description', 'Party', 'Chamber', 'DW1', 'PassH', 'PassS', 'Postal']]

    # Drop bills with missing data
    cbp.dropna(inplace=True)

    # Make Majors an integer
    cbp['Major'] = cbp['Major'].apply(lambda x: int(x))

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

    description_cbp = description_cbp.str.replace("'s", "s") 
    description_cbp = description_cbp.str.replace(r'[?"]{2,}|[`]', '', regex=True)
    description_cap = description_cap.str.replace("'s", "s") 
    description_cap = description_cap.str.replace(r'_\?\?|["]{2,}|[`]', '', regex=True) # 1 to 8 times in the 10K sample
    
    condition = description_cap!=description_cbp
    description_cbp[condition] = description_cbp[condition].str.replace('\' ', ' ')
    description_cbp[condition] = description_cbp[condition].str.replace(' \'', ' ')
    description_cap[condition] = description_cap[condition].str.replace('\' ', ' ')
    description_cap[condition] = description_cap[condition].str.replace(' \'', ' ')
    description_cap[condition] = description_cap[condition].str.replace("'", "")

    condition = description_cap!=description_cbp
    return condition

def merge_cap_cbp(cap, cbp):
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
        
    major_code = {
         1: "Macroeconomics",
         2: "Civil Rights, Minority Issues, and Civil Liberties",
         3: "Health",
         4: "Agriculture",
         5: "Labor and Employment",
         6: "Education",
         7: "Environment",
         8: "Energy",
         9: "Immigration",
        10: "Transportation",
        11: "Law, Crime, and Family Issues",
        12: "Social Welfare",
        13: "Community Development and Housing Issues",
        14: "Banking, Finance, and Domestic Commerce",
        15: "Defense",
        16: "Space, Science, Technology, and Communications",
        17: "Foreign Trade",
        18: "International Affairs and Foreign Aid",
        19: "Government Operations",
        20: "Public Lands and Water Management"
    }

    chamber_code = {
        0: 'House', 
        1: 'Senate'
    }

    party_code = {
        100: 'Democrat', 
        112: 'Conservative',
        200: 'Republican',
        328: 'Independent'
    }

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
    bills['Major'] = bills['Major'].apply(lambda x: major_PAP2Ours[x])

    # Add MajorText column 
    bills['MajorText'] = bills['Major'].apply(lambda x: major_code[x])

    # Add Chamber codes
    bills['Chamber'] = bills['Chamber'].apply(lambda x: chamber_code[x])

    # Add Party codes
    bills['Party'] = bills['Party'].apply(lambda x: party_code[x])

    # Rearrange columns
    bills = bills[['BillID', 'Year', 'Major', 'MajorText', 'Party', 'PassH', 'PassS', 'Description', 'DW1', 'Chamber', 'Postal']]
    bills.reset_index(drop=True)
    print(len(bills)) # n = 228387
    return()

def sample_bills(bills, n_examples = 5, seed = 123):
    # Bills used for few-shot prompting
    examples = bills.groupby('Major').sample(n=1, random_state=seed).reset_index(drop=True)[:(n_examples*3)] 

    condition = bills['BillID'].apply(lambda x: x not in examples['BillID'].to_list())
    bills = bills[condition]
    print(f'Removed {len(examples)} examples from bills data.')

    bills_10k = bills.sample(n=10_000, random_state=seed)
    return(bills_10k, examples)

def main():
    # Define directories
    data_dir = os.path.join(REPO_DIR, 'Data')
    fig_dir = os.path.join(REPO_DIR, 'Figures and Tables')
    os.makedirs(data_dir, exist_ok=True)
    os.makedirs(fig_dir, exist_ok=True)

    # CAP and CBP data paths
    path_cap = 'https://comparativeagendas.s3.amazonaws.com/datasetfiles/US-Legislative-congressional_bills_19.3_3_3.csv' 
    path_cbp_80_92 = 'http://congressionalbills.org/billfiles/bills80-92.zip' 
    path_cbp_93_114 = 'http://congressionalbills.org/billfiles/bills93-114.zip' 
    # path_cap = os.path.join(data_dir, 'CAP.csv')
    # path_cbp_80_92 = os.path.join(data_dir, 'CBP80-92.txt')
    # path_cbp_93_114 = os.path.join(data_dir, 'CBP93-114.csv')
    
    # Load and clean CAP
    cap = load_cap(path_cap)
    cap = clean_cap(cap)
    cap.to_csv(os.path.join(data_dir, "cap.csv"), index=False)
    print(f'Saved cap.csv, n = {len(cap)}, at {data_dir}')

    # Load and clean CBP
    cbp = load_cbp(path_cbp_80_92, path_cbp_93_114)
    cbp.to_csv(os.path.join(data_dir, "cbp2.csv"), index=False)
    cbp = clean_cbp(cbp)
    cbp.to_csv(os.path.join(data_dir, "cbp.csv"), index=False)
    print(f'Saved cbp.csv, n = {len(cbp)}, at {data_dir}')

    # Merge CAP and CBP data
    bills = merge_cap_cbp(cap, cbp)
    bills.to_csv(os.path.join(data_dir, "bills.csv"), index=False)
    print(f'Saved bills.csv, n = {len(bills)}, at {data_dir}')

    # Draw 10k bills and 5*3=15 bill examples used for few-shot prompts.
    bills_10k, bills_examples = sample_bills(bills, n_examples = 15, seed = 123)
    bills_10k.to_csv(os.path.join(data_dir, 'bills_10k.csv'), index=False)
    print(f'Saved bills_10k.csv, n = {len(bills_10k)}, at {data_dir}')

    # Split the 15 examples into 3 sets for the 3 few-shot prompts
    bills_examples['ExampleSetNum'] = np.repeat([1, 2, 3], repeats=15/3)
    bills_examples.to_csv(os.path.join(data_dir, 'bills_examples.csv'), index=False)
    print(f'Saved bills_examples.csv, n = {len(bills_examples)}, at {data_dir}')

    # Plot the frequency of the 10K bills over years
    plt.figure(figsize=(10, 6))
    bills_10k['Year'].hist(bins=range(int(bills_10k['Year'].min()), int(bills_10k['Year'].max()) + 1, 2), edgecolor='black')
    plt.title('A histogram of the frequency of the 10K bills over years')
    plt.xlabel('Year')
    plt.ylabel('Number of Bills')
    plt.grid(False)
    plt.savefig(os.path.join(fig_dir, 'A histogram of the frequency of the 10K bills over years.png'))
    print(f'Saved figures at {fig_dir}')

# Run the main function when the script is executed
if __name__ == "__main__":
    main()