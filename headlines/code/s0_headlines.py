import pandas as pd
import datetime as dt
import os
import numpy as np
import pandas_market_calendars as pmc
from helpers import try_float
from constants import month_batches, step0_path

headlines_file_path = "./data/raw/headlines2019.csv"
factors_file_path = "./data/raw/F-F_Research_Data_Factors_daily.csv"
WRDS_CAPM_path = "./data/raw/CAPM_returns.csv"
WRDS_FF3_path = "./data/raw/FF3_returns.csv"

def month_to_num(month):
    return dt.datetime.strptime(month, "%b").month

def load_data(headlines_file_path, factors_file_path, WRDS_CAPM_path, WRDS_FF3_path):
    data = pd.read_csv(headlines_file_path)
    factors = pd.read_csv(factors_file_path)
    WRDS_CAPM = pd.read_csv(WRDS_CAPM_path)
    WRDS_FF3 = pd.read_csv(WRDS_FF3_path)

    # Convert date columns to datetime
    data['date'] = pd.to_datetime(data['date'])
    factors['date'] = pd.to_datetime(factors['Unnamed: 0'], format='%Y%m%d')
    WRDS_CAPM['DATE'] = pd.to_datetime(WRDS_CAPM['DATE'])
    WRDS_FF3['DATE'] = pd.to_datetime(WRDS_FF3['DATE'])

    # Drop unnecessary columns
    factors.drop('Unnamed: 0', axis=1, inplace=True)
    return data, factors, WRDS_CAPM, WRDS_FF3

def process_returns(WRDS, factors):
    WRDS = WRDS.rename(columns=str.lower)[['permno', 'ret', 'exret', 'date', 'b_mkt']]
    WRDS[['ret', 'exret']] = WRDS[['ret', 'exret']].map(try_float)
    WRDS = WRDS.merge(factors.rename(columns=str.lower), on='date', how='left')
    WRDS['exret_hat'] = WRDS['ret'] - WRDS['rf'] - WRDS['b_mkt'] * WRDS['mkt-rf']
    return WRDS


# Get trading days using NYSE calendar
def get_trading_days(date, num_days=10):
    nyse = pmc.get_calendar('XNYS')
    return nyse.valid_days(pd.Timestamp(date), pd.Timestamp(date) + pd.Timedelta(days=20))[:num_days+1].tz_convert(None).tolist()

# Main function to execute the data processing
def main(months):
    data, factors, WRDS_CAPM, WRDS_FF3 = load_data(headlines_file_path, factors_file_path, WRDS_CAPM_path, WRDS_FF3_path)
    print("Loaded data")

    for month in months:
        # Filter data for the year 2019 and the selected month
        data_2019 = data.loc[(data['date'].dt.year == 2019) & (data['date'].dt.month == month_to_num(month))]
        monthly_data = data_2019[["date", "permno", "headline", "ret", "company_name",
                                  "ret_fd1", "ret_fd5", "ret_fd10", "ret_ld1", "ret_ld2", "ret_ld3"]].copy()

        # Convert realized returns to percentage and save
        decimal_cols = ["ret", "ret_fd1", "ret_fd5", "ret_fd10", "ret_ld1", "ret_ld2", "ret_ld3"]
        monthly_data.loc[:, decimal_cols] = monthly_data[decimal_cols].apply(lambda x: x * 100)
        monthly_data.drop_duplicates(inplace=True)

        os.makedirs(f"{step0_path}/realized", exist_ok=True)
        monthly_data.to_csv(f"{step0_path}/realized/{month}19_realized.csv", index=False)
        print(f"Saved realized returns for {month}")

        # Precompute trading days for all dates in the monthly data
        trading_days = {d: get_trading_days(d) for d in monthly_data['date'].unique()}
        for i in range(1, 11):
            monthly_data[f'date_{i}'] = monthly_data['date'].map(lambda d: trading_days[d][i] if d in trading_days else pd.NaT)

        # Process WRDS returns for CAPM and FF3
        returns_data = {'CAPM': process_returns(WRDS_CAPM, factors), 'FF3': process_returns(WRDS_FF3, factors)}
        
        # Merge returns data dynamically for both CAPM and FF3
        for key, returns in returns_data.items():
            merged = monthly_data.merge(returns, on=["date", "permno"], how='inner').drop(columns="ret_x").rename(columns={"ret_y": "ret"})
            for i in range(1, 11):
                merged = merged.merge(returns[["date", "permno", "exret"]],
                                      left_on=[f'date_{i}', "permno"],
                                      right_on=["date", "permno"],
                                      how='left', suffixes=('', f'_{i}'))
            merged.drop(columns=[f'date_{i}' for i in range(1, 11)], inplace=True)

            os.makedirs(f"{step0_path}/abnormal_{key}", exist_ok=True)
            merged.to_csv(f"{step0_path}/abnormal_{key}/{month}19_abnormal_{key}.csv", index=False)
            print(f"Saved abnormal returns for {month} using {key}")


if __name__ == "__main__":
    months = month_batches
    main(months)

