import os
import pandas as pd

# Define the root directory where your CSV files are stored
root_dir = "./data/step5_returns_merged"

# List of main directories
main_dirs = ["cumulative", "CAPM", "FF3"]

# List of model subdirectories
model_dirs = ["gpt-3.5-turbo", "gpt-4o", "gpt-4o-mini"]

# List of question directories
question_dirs = ["q1", "q2", "q3", "q4", "q5"]

# List of month directories
month_dirs = ["jan", "feb", "mar", "apr", "may", "jun", 
              "jul", "aug", "sep", "octfirst", "octsecond", 
              "nov", "dec"]

# Initialize a list to store the results
summary_data = []

# Loop through each main directory
for main_dir in main_dirs:
    main_dir_path = os.path.join(root_dir, main_dir)
    
    # Loop through each model subdirectory
    for model_dir in model_dirs:
        model_dir_path = os.path.join(main_dir_path, model_dir)
        
        # Loop through each question subdirectory
        for question_dir in question_dirs:
            
            for month_dir in month_dirs:

                month_dir = question_dir + "_" + month_dir + "19"

                month_path = os.path.join(model_dir_path, question_dir, month_dir)

                # Loop through each CSV file in the question subdirectory
                if os.path.exists(month_path):
                    
                    for csv_file in os.listdir(month_path):
                        if csv_file.endswith(".csv"):
                            file_path = os.path.join(month_path, csv_file)
                            
                            # Load the CSV file into a pandas DataFrame
                            df = pd.read_csv(file_path)
                            row_count = len(df)
                            
                            # Count the number of rows where the "headline type" column is empty
                            empty_headline_count = df['headline type'].isna().sum()
                            
                            # Append the results to the summary data list
                            summary_data.append({
                                "Main Directory": main_dir,
                                "Model": model_dir,
                                "Month": month_dir,
                                "Question": question_dir,
                                "File": csv_file,
                                "Row Count": row_count,
                                "Empty Headline Type Count": empty_headline_count
                            })

# Convert the summary data to a pandas DataFrame
summary_df = pd.DataFrame(summary_data)

# Save the summary DataFrame to a CSV file
summary_df.to_csv("response_counts_batch.csv", index=False)
