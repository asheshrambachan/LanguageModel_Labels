# Congressional Bills Data Cleaning

## Overview

This repository contains the scripts and data for cleaning congressional bills data for further analysis. The code is based on the [replication code](https://osf.io/gjt87/) from [Egami et al. (2023)](https://arxiv.org/abs/2306.04746).

## Data Sources

The primary data sources are listed below. You don’t need to download the data separatly as this is done in the notebook.

- [Comparative Agendas Project (CAP)](https://www.comparativeagendas.net/#congressional_hearings)
- [Congressional Bills Project (CBP)](http://congressionalbills.org/download.html)


## Usage

Open the [`cleaning.ipynb`](https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/congressional_bills/01_cleaning_and_data/cleaning.ipynb) notebook and run all cells to perform data cleaning. The cleaned dataset will be saved as `bills.csv`. Due to GitHub data size constraints, the cleaned data in this repo is included in [`Archive.zip`](https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/congressional_bills/01_cleaning_and_data/bills.csv.zip).

## Cleaning Remarks

While our approach shares similarities with Egami's method, we have made several key modifications:

1. We observed few inconsistencies in bill IDs in the datasets and corrected them. We consider bills of the same `BillID_corrected` as duplicates and drop them from both CAP and CBP. Note that coding system for `Major` topic ID is mutually exclusive: each `BillID_corrected` is mapped to only one `Major` topic.
2. Similar to Egami et al. (2023), we drop bills with missing `Major_CAP` values, and we don't consider `Major_CBP`. We also keep all major topic IDs except for topic 99. 
3. Egami et al. (2023) drops bills with missing values in any of these columns: `Party_CAP`, `PassS_CAP`, and `PassH_CAP`. We observed that some of those missing variables exists in the CBP data. To ensure we don’t exclude potentially valid data, we currently drop bills with missing `Party_CBP`, `PassS_CBP`, and `PassH_CBP`. Columns from both data sources are currently kept in this version of the data.
4. Egami et al. (2023) considers bills of the same description as duplicates and drop them. We observed that those bills are not necessarly duplicates as they vary in variables such as `Year`, `State`, ... etc. We include those variables in our identification of duplicates. We also ensure descriptions are case insensitive by converting them to lowercase.
5. Following Egami et al. (2023), we impute missing `DW1` scores using the avalible data mean. Both original, `DW1`, and imputed, `DW1_impute`, columns are included in the data.
6. Egami et al. (2023) drops variables/columns with any missing values. However, we keep those that are mostly complete, with less than 10% of their observations missing. 


## To-Dos

- [ ] Decide on which data source, CAP or CBP, to rely on for `Major`, `Description`, `Party`, `PassS`, and `PassH`. Currently, I go with CBP.
- [ ] Decide whether to exclude columns with any missing values as in Egami et al. (2023)
- [x] Create a new coding for major topics IDs as topic 11 is not included in the data
- [ ] Create a codebook for the variables based on ICPSR