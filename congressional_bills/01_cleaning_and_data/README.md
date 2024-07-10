# Congressional Bills Data Cleaning

## Overview

This repository contains the scripts and data for cleaning congressional bills data for further analysis. The code is based on the [replication code](https://osf.io/gjt87/) from [Egami et al. (2023)](https://arxiv.org/abs/2306.04746).

## Data Sources

The primary data sources are listed below. You don’t need to download the data separatly as this is done in the notebook.

- [Comparative Agendas Project (CAP)](https://www.comparativeagendas.net/#congressional_hearings)
- [Congressional Bills Project (CBP)](http://congressionalbills.org/download.html)


## Usage

Open the Jupyter notebook and run all cells to perform data cleaning. The cleaned dataset will be saved as `bills.csv`.

## Cleaning Remarks

While our approach shares similarities with Egami's method, we have made several key modifications:

1. We observed few inconsistencies in bill IDs in the datasets and corrected them.
2. Egami drops columns with any missing values. However, we keep those that are mostly complete, with less than 10% of their observations missing. 
3. Following Egami, we impute missing DW1 scores using the mean, and keep both original and imputed column, `DW1` and `DW1_imputed`. 
4. Similar to Egami, we use major topic ID from CAP rather than CBP to drops bills with missing `Major_CAP` values. We also keep all major topic IDs except for topic 99. 
5. Egami drops observations with party affliation, `Party_CAP`, or Senate/House pass status, `PassS_CAP` and `PassH_CAP`. We observed that some of those missing variables exists in the CBP data, and drop observations with missing `Party_CBP`, `PassS_CBP`, and `PassH_CBP` to ensure we don’t exclude potentially valid data. Currently we keep columns from both data sources.
6. Egami considers bills of the same description as duplicates. In our implemntation, we include other variables along with the description. We also ensure descriptions are case insensitive by converting them to lowercase before dropping duplicates.

## To-Dos

- Decide on which data source, CAP or CBP, to rely on for `Party`, `PassS`, and `PassH`
- Decide whether to exclude columns with any missing values as in Egami
- Create a new major topics IDs as topic 11 is not in the data