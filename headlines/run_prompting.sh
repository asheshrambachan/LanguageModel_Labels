#!/bin/bash

# Store the root directory
ROOT_DIR=$(pwd)

# Path to Python and R scripts
PYTHON_DIR="$ROOT_DIR/code"

# List of Python scripts to run
python_scripts=("s0_headlines.py", "s1_write_prompts.py", "s2_batch_prompt.py")

# Run specific Python scripts
echo "Running Python scripts..."
for py_script in "${python_scripts[@]}"; do
    echo "Executing $py_script..."
    python "$PYTHON_DIR/$py_script"
done
