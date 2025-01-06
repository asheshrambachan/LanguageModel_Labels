## How to get `CAPM_returns.csv` data

Step 1: Choose your date range.

2019-01-01
to
2019-12-31


Step 2: Apply your company codes.
What format are your company codes?

Autocomplete
- [x] PERMNO
- [] Ticker

Select an option for entering your company codes:
- [] Search Name or Ticker
- [] Select Saved Codes List
- [] Browse... Company Codes Uploaded Files
- [x] Search the entire database

Step 3: Frequency Selection

Frequency
- [x] Daily (trading days)
- [] Weekly
- [] Monthly

Estimation Window: 252 (default)
Minimum Window: 126 (default)

Step 4: Risk Model
- [] Scholes-William (only available for Daily)
- [x] Market Model
- [] Fama French 3 Factors
- [] Fama French/Carhart 4 Factors

Step 5: Return Type
- [x] Regular Return
- [] Log Return

Step 6: What variables do you want to include in the output?

- [x] PERMNO
- [x] Date of Observation
- [x] Returns
- [x] Ticker

Step 7: How would you like the query output?
Output Format: comma-delimited text (*.csv)
Compression Type: Uncompressed
Date Format: YYYY-MM-DD. (e.g. 1984-07-25)

Submit Form

Once the status of the query is Success
Download .csv Output
Then rename the file as `CAPM_returns.csv`



## How to get `F-F_Research_Data_Factors_daily.csv` data

```py
factors_file_path = "https://web.archive.org/web/20240329224745/https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/ftp/F-F_Research_Data_Factors_daily_CSV.zip"

import requests
from io import BytesIO
from zipfile import ZipFile

# Download the zip file from the URL
response = requests.get(factors_file_path)

# Open the zip file
with ZipFile(BytesIO(response.content)) as z:
    # Extract the first file from the zip (adjust if necessary)
    file_name = z.namelist()[0]
    # Load the CSV into a DataFrame
    factors = pd.read_csv(z.open(file_name), skiprows=4)

    # Skip the last 2 rows
    factors = factors.iloc[:-2]

factors.to_csv('~/Documents/LanguageModel_Labels/estimation_headlines/data/raw/F-F_Research_Data_Factors_daily.csv')
```