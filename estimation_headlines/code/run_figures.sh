#!/bin/bash

# Get the directory of this script (which should be 'headlines/code')
script_dir="$(cd "$(dirname "$0")" && pwd)"
# Move up one directory, which should get us to 'headlines'
parent_dir="$(dirname "$script_dir")"

cd "$parent_dir" || {
    echo "Failed to change directory to $parent_dir. Exiting."
    exit 1
}

# Now we are in 'headlines', but the R scripts are in 'headlines/code/produce_figures'
Rscript "code/produce_figures/heatmaps.R"
Rscript "code/produce_figures/tables.R"
Rscript "code/produce_figures/tstat_comparison_v1.R"
Rscript "code/produce_figures/tstat_comparison_v2.R"

echo "All figure scripts executed successfully."
