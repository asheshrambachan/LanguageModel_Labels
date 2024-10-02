#!/bin/bash

# Store the root directory
ROOT_DIR=$(pwd)

# Paths to R scripts
R_CODE_DIR="$ROOT_DIR/code"
R_FIGURES_DIR="$ROOT_DIR/code/produce_figures"

# List of R scripts to run from 'code'
code_r_scripts=("s9.1_realized_returns_clustered.R" "s9.2_abnormal_returns_clustered.R" "s9.3_realized_returns_robust.R")

# List of R scripts to run from 'code/produce_figures'
figures_r_scripts=("heatmaps.R" "summary_figures_and_tables.R" "tstat_comparison.R")

# Run R scripts in 'code' directory
echo "Running R scripts in the 'code' directory..."
for r_script in "${code_r_scripts[@]}"; do
    echo "Executing $r_script..."
    Rscript "$R_CODE_DIR/$r_script"
done

# Run R scripts in 'code/produce_figures' directory
echo "Running R scripts in the 'code/produce_figures' directory..."
for r_script in "${figures_r_scripts[@]}"; do
    echo "Executing $r_script..."
    Rscript "$R_FIGURES_DIR/$r_script"
done

echo "All figures and tables have been produced."
