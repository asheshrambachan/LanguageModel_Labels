#!/bin/bash

# Change the working directory to one level up (headlines directory)
script_dir="$(cd "$(dirname "$0")" && pwd)"
parent_dir="$(dirname "$script_dir")"
cd "$parent_dir" || {
    echo "Failed to change directory to $parent_dir. Exiting."
    exit 1
}

echo "Current working directory: $(pwd)"

# List of Python scripts to run (relative to the original script location)
python_scripts=("s0_headlines.py" "s1_write_prompts.py" "s2_batch_prompt.py" "s3_batch_status.py")

# Run specific Python scripts
echo "Running Python scripts..."
for py_script in "${python_scripts[@]}"; do
    echo "Executing $py_script..."
    python "code/$py_script"
done
