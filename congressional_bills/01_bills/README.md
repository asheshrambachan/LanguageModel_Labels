# Congressional Bills Data Cleaning

## Overview

This repository contains the scripts and data for cleaning congressional bills data for further analysis. The code is based on the [replication code](https://osf.io/gjt87/) from [Egami et al. (2023)](https://arxiv.org/abs/2306.04746).

## Data Sources

The primary data sources are listed below. You don’t need to download the data separatly as this is done in the notebook.

- [Comparative Agendas Project (CAP)](https://www.comparativeagendas.net/#congressional_hearings)
- [Congressional Bills Project (CBP)](http://congressionalbills.org/download.html)

## Cleaned Data

Due to GitHub size limit, all data generated from this notebook and their corresponding codebook can be downloaded from [here](https://drive.google.com/drive/folders/1LrlEcUn5U5U7kQw7Q-t9hoMFf8TCFoT0?usp=sharing).

## Usage

Open the [`bills_cleaning.ipynb`](https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/congressional_bills/01_bills/bills_cleaning.ipynb) notebook and run all cells to perform data cleaning. The cleaned dataset will be saved as `bills.csv`. Due to GitHub data size constraints, the cleaned data in this repo is included in [`bills.csv.zip`](https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/congressional_bills/01_bills/bills.csv.zip).

## Cleaning Remarks

While our approach shares similarities with Egami's method, we have made several key modifications:

1. We observed few inconsistencies in bill IDs in the datasets and corrected them. We consider bills of the same `BillID` as duplicates and drop them from both CAP and CBP. Note that coding system for `Major` topic ID is mutually exclusive: each `BillID` is mapped to only one `Major` topic.
2. Bills that varies in `Major`, `Description`, `Party`, `PassS`, `PassH`, `Chamber` in CBP and CAP are dropped version.
3. Similar to Egami et al. (2023), we drop bills with missing `Major`, `Description`, `Party`, `PassS`, `PassH`, `Year`, `Chamber` values. We also keep all major topic IDs except for topic 99. 
4. As in Egami et al. (2023), we consider bills of the same `Description` as duplicates and drop them. We also ensure descriptions are case insensitive by converting them to lowercase.
5. Egami et al. (2023), impute missing `DW1` scores by averaging over bills. We average over unique bill sponsor `NameFull` and their `DW1` score. Both original, `DW1`, and imputed, `DW1_impute`, columns are included in the data.
6. Similar to Egami et al. (2023), we drops variables/columns with any missing values except `DW1`. 

## To-Dos

- [x] Create a new coding for major topics IDs as topic 11 is not included in the data
- [x] Create a codebook for the variables based on ICPSR
- [x] Drop bills that varies in `Description` between CBP and CAP.
- [x] Drop columns with any missing values as in Egami et al. (2023)
- [x] Correct CAP `Chamber` ID. 
- [x] Drop bills with inconsistent values in CAP and CBP: `Major`, `Description`, `Party`, `PassS`, and `PassH`.
- [x] sample 15 example bills, and 10K bills (without those 15)
- [x] Add seed for replication
- [ ] Update codebook