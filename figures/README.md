# Figures

This subdirectory contains scripts for generating the figures presented in the paper. Figures are organized by task type and dataset.

## Directory Structure

- `code/`: Contains the R scripts for generating figures.
    - `prediction_headlines/`: Figures scripts for prediction tasks using financial news headlines.
    - `prediction_cb/`: Figures scripts for prediction tasks using Congressional bills.
    - `estimation_headlines/`: Figures scripts for estimation tasks using financial news headlines.
    - `estimation_cb/`: Figures scripts for estimation tasks using Congressional bills.
- `output/`: Contains the generated figures files (`.jpeg` and `.tex`) for each task and dataset.
    - Subdirectories mirror the `code/` structure.


## Replication Options

You can replicate the figures using the following methods:

1. **Full Replication:** To generate all figures for all tasks and datasets, run `run_all.sh` script as follows:
    ```
    chmod +x ./figures/code/run_all.sh
    ./figures/code/run_all.sh
    ```

2. **Partial Replication:** To generate a specific figure, run its relevant R script. For example:
    ```
    Rscript ./figures/code/prediction_cb/fig_prediction_gpt4o_cb_base_prompt.R
    ```

## Notes
- All necessary data files are included in this repository. There is no need to regenerate data for figures creation.
- Figures are saved within the `output/` subdirectory.

