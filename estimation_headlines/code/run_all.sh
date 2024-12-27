#!/bin/bash

# Run analysis script
bash estimation_headlines/code/run_analysis.sh

# Run figures script
bash estimation_headlines/code/run_figures.sh

# Run prompting script
bash estimation_headlines/code/run_prompting.sh

# Run regressions script
bash estimation_headlines/code/run_regressions.sh

echo "All scripts executed successfully!"
