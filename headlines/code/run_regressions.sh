#!/bin/bash

# Change the working directory to one level up (headlines directory)
script_dir="$(cd "$(dirname "$0")" && pwd)"
parent_dir="$(dirname "$script_dir")"
cd "$parent_dir" || {
    echo "Failed to change directory to $parent_dir. Exiting."
    exit 1
}

# List of R scripts to run
r_scripts=("s9.1_realized_returns_clustered.R" "s9.2_abnormal_returns_clustered.R" "s9.3_realized_returns_robust.R" "s9.4_realized_returns_fe.R")

# Run specific R scripts
echo "Running R scripts..."
for r_script in "${r_scripts[@]}"; do
    echo "Executing $r_script..."
    Rscript "$script_dir/$r_script"
    if [ $? -ne 0 ]; then
        echo "Error running $r_script"
        exit 1
    fi
done

echo "All specified R scripts have been executed successfully."
