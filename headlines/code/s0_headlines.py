# import stuff
import pandas as pd
import datetime as dt
import numpy as np
import pandas_market_calendars as pmc
from helpers import try_float

# Load WRDS data and factor files
def load_data(headlines_file_path, factors_file_path, WRDS_CAPM_path, WRDS_FF3_path):
    data = pd.read_parquet(headlines_file_path)
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

# Process returns data
def process_returns(WRDS, factors, column_renames):
    WRDS = WRDS.rename(columns=lambda s: s.lower())
    WRDS = WRDS[['permno', 'ret', 'exret', 'date', 'b_mkt']]
    
    for col in ['ret', 'exret']:
        WRDS[col] = WRDS[col].apply(try_float)

    WRDS = WRDS.merge(factors.rename(columns=lambda s: s.lower()), on='date', how='left')
    WRDS['exret_hat'] = WRDS['ret'] - WRDS['rf'] - WRDS['b_mkt'] * WRDS['mkt-rf']
    return WRDS

# Get trading days using NYSE calendar
def get_trading_days(date, num_days=10):
    nyse = pmc.get_calendar('XNYS')
    start_date = pd.Timestamp(date)
    trading_days = nyse.valid_days(start_date, start_date + pd.Timedelta(days=20))
    trading_days_naive = trading_days.tz_convert(None)
    return trading_days_naive[:num_days + 1].tolist()

# Main function to execute the data processing
def main(daily_file_path, factors_file_path, WRDS_CAPM_path, WRDS_FF3_path, month, output_dir):
    # Load data
    data, factors, WRDS_CAPM, WRDS_FF3 = load_data(daily_file_path, factors_file_path, WRDS_CAPM_path, WRDS_FF3_path)

    # Filter data for the year 2019 and the selected month
    data_2019 = data[(data['date'].dt.year == 2019) & (data['date'].dt.month == month)]
    monthly_data = data_2019[["date", "permno", "headline", "ret", "company_name",
                              "ret_fd1", "ret_fd5", "ret_fd10", "ret_ld1", "ret_ld2", "ret_ld3"]]

    # Convert returns to percentage
    decimal_cols = ["ret", "ret_fd1", "ret_fd5", "ret_fd10", "ret_ld1", "ret_ld2", "ret_ld3"]
    monthly_data[decimal_cols] = monthly_data[decimal_cols].apply(lambda x: x * 100)
    monthly_data.drop_duplicates(inplace=True)

    # Save the processed monthly data
    monthly_data.to_csv(f"{output_dir}/oct19_realized.csv", index=False)

    # Process WRDS returns
    returns_CAPM = process_returns(WRDS_CAPM, factors, column_renames=['ret', 'exret'])
    returns_FF3 = process_returns(WRDS_FF3, factors, column_renames=['ret', 'exret'])

    # Add trading days to monthly data
    monthly_data['trading_days'] = monthly_data['date'].apply(get_trading_days)

    # Add date columns
    for i in range(1, 11):
        monthly_data[f'date_{i}'] = monthly_data['trading_days'].apply(lambda x: x[i])

    monthly_data.drop('trading_days', axis=1, inplace=True)

    # Merge CAPM and FF3 returns with monthly data
    frame_CAPM = monthly_data.merge(returns_CAPM, on=["date", "permno"], how='inner').drop(columns="ret_x").rename(columns={"ret_y": "ret"})
    frame_FF3 = monthly_data.merge(returns_FF3, on=["date", "permno"], how='inner').drop(columns="ret_x").rename(columns={"ret_y": "ret"})

    # Merge returns data dynamically
    date_columns = [f'date_{i}' for i in range(1, 11)]

    merged_CAPM = frame_CAPM.copy()
    merged_FF3 = frame_FF3.copy()

    for i, date_col in enumerate(date_columns, start=1):
        merged_CAPM = merged_CAPM.merge(returns_CAPM[["date", "permno", "exret"]],
                                        left_on=[date_col, "permno"],
                                        right_on=["date", "permno"],
                                        how='inner',
                                        suffixes=('', f'_{i}'))
        merged_FF3 = merged_FF3.merge(returns_FF3[["date", "permno", "exret"]],
                                      left_on=[date_col, "permno"],
                                      right_on=["date", "permno"],
                                      how='inner',
                                      suffixes=('', f'_{i}'))

    # Remove date columns after the merge
    merged_CAPM.drop(columns=date_columns, inplace=True)
    merged_FF3.drop(columns=date_columns, inplace=True)

    # Save the final data
    merged_CAPM.to_csv(f"{output_dir}/oct19_CAPM.csv", index=False)
    merged_FF3.to_csv(f"{output_dir}/oct19_FF3.csv", index=False)

if __name__ == "__main__":
    # Define paths
    headlines_file_path = "./data/returns_data/headlines2019.csv"
    factors_file_path = "./data/returns_data/F-F_Research_Data_Factors.csv"
    WRDS_CAPM_path = "./data/returns_data/CAPM_returns.csv"
    WRDS_FF3_path = "./data/returns_data/FF3_returns.csv"
    output_dir = "./data/returns_data/"
    
    # Execute main function for October
    main(headlines_file_path, factors_file_path, WRDS_CAPM_path, WRDS_FF3_path, months=[10], output_dir=output_dir)

