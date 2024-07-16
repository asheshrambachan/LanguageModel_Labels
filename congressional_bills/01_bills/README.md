# Congressional Bills Data Cleaning

## Overview

This repository contains the scripts and data for cleaning congressional bills data for further analysis. The code is based on the [replication code](https://osf.io/gjt87/) from [Egami et al. (2023)](https://arxiv.org/abs/2306.04746).

## Data Sources

The primary data sources are listed below. You don’t need to download the data separatly as this is done in the notebook.

- [Comparative Agendas Project (CAP)](https://www.comparativeagendas.net/#congressional_hearings)
- [Congressional Bills Project (CBP)](http://congressionalbills.org/download.html)


## Usage

Open the [`bills_cleaning.ipynb`](https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/congressional_bills/01_bills/bills_cleaning.ipynb) notebook and run all cells to perform data cleaning. The cleaned dataset will be saved as `bills.csv`. Due to GitHub data size constraints, the cleaned data in this repo is included in [`bills.csv.zip`](https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/congressional_bills/01_bills/bills.csv.zip).

## Cleaning Remarks

While our approach shares similarities with Egami's method, we have made several key modifications:

1. We observed few inconsistencies in bill IDs in the datasets and corrected them. We consider bills of the same `BillID` as duplicates and drop them from both CAP and CBP. Note that coding system for `Major` topic ID is mutually exclusive: each `BillID` is mapped to only one `Major` topic.
2. Similar to Egami et al. (2023), we drop bills with missing `Major`, `Description`, `Party`, `PassS`, and `PassH` values. We also keep all major topic IDs except for topic 99. Currently, I use data from CAP to do that which has more missing values compared to CBP data. Some bills have different values in CBP and CAP and both are kept in this version.
3. Egami et al. (2023) considers bills of the same description as duplicates and drop them. We observed that those bills are not necessarly duplicates as they vary in variables such as `Year`, `State`, ... etc. We drop bills that are identical in both the `Description` and `Major` topic ID. We also ensure descriptions are case insensitive by converting them to lowercase.
4. Egami et al. (2023), impute missing `DW1` scores by averaging over bills. We average over unique bill sponsor `NameFull` and their `DW1` score. Both original, `DW1`, and imputed, `DW1_impute`, columns are included in the data.
5. Egami et al. (2023) drops variables/columns with any missing values. However, we keep those that are mostly complete, with less than 10% of their observations missing. 


## To-Dos

- [x] Create a new coding for major topics IDs as topic 11 is not included in the data
- [x] Create a codebook for the variables based on ICPSR
- [ ] Drop columns with any missing values as in Egami et al. (2023)
- [ ] Drop bills that varies in `Description` between CBP and CAP.
- [ ] Correct CAP `Chamber` ID. 
- [ ] Figure out why `Party`, `PassS`, and `PassH` are in inconsistent between CAP and CBP.
- [ ] Decide on which data source, CAP or CBP, to rely on for `Major`, `Description`, `Party`, `PassS`, and `PassH`. Currently, I go with CBP.