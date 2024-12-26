# Tables

This subdirectory contains scripts for generating the tables presented in the paper. Tables are organized by task type and dataset.

## Directory Structure

- `code/`: Contains the R scripts for generating tables.
    - `prediction_headlines/`: Tables scripts for prediction tasks using financial news headlines.
    - `prediction_legislation/`: Tables scripts for prediction tasks using Congressional legislation.
    - `estimation_headlines/`: Tables scripts for estimation tasks using financial news headlines.
    - `estimation_legislation/`: Tables scripts for estimation tasks using Congressional legislation.
- `output/`: Contains the generated `.tex` table files for each task and dataset.
    - Subdirectories mirror the `code/` structure.


## Replication Options

You can replicate the tables using the following methods:

1. **Full Replication:** To generate all tables for all tasks and datasets, run `run_all.sh` script as follows:
    ```
    chmod +x ./tables/code/run_all.sh
    ./tables/code/run_all.sh
    ```

2. **Partial Replication:** to generate a specific table, run its relevant R script. For example:
    ```
    Rscript ./tables/code/prediction_legislation/tab_completion_cosine_euclidean_gpt4o_cb_base_prompt.R
    ```

## Notes
- All necessary data files are included in this repository. There is no need to regenerate data for table creation.
- Tables are saved within the `output/` subdirectory.

