#!/bin/bash

# Store the root directory
ROOT_DIR=$(pwd)

# Path to Python and R scripts
CODE_DIR="${ROOT_DIR}/code"

# List of Python scripts to run
python_scripts=("s4_process_responses.py", "s5_merge_returns.py", "s6_common_sample.py", "s7_batch_metrics.py", "s8_bad_responses.py")

# Run specific Python scripts
echo "Running Python scripts..."
for py_script in "${python_scripts[@]}"; do
    echo "Executing ${py_script}..."
    python "${CODE_DIR}/${py_script}"
done

echo "All scripts executed."