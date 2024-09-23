#!/bin/bash

# Step 1: Data Cleaning
echo "Starting data cleaning..."
python ./Code/1_clean_bills.py

# Step 2: Prompt Creation, Querying and Decoding LLM Responses
echo "Creating prompts..."
python ./Code/2.1_create_prompts.py

echo "Querying LLMs..."
python ./Code/2.2_query_llm.py

echo "Downloading LLM responses..."
python ./Code/2.3_download_responses.py

echo "Decoding LLM responses..."
python ./Code/2.4_decode_responses.py

# Step 3: Simulation Runs & Model Evaluation
echo "Running LHS simulations..."
Rscript ./Code/3.1_run_lhs_simulations.r

echo "Running RHS simulations..."
Rscript ./Code/3.2_run_rhs_simulations.r

echo "Summarizing LHS simulations..."
Rscript ./Code/3.3_summarize_lhs_simulations.r

echo "Summarizing RHS simulations..."
Rscript ./Code/3.4_summarize_rhs_simulations.r

# Step 4: Figure and Table Generation
echo "Estimating LLM prediction errors..."
python ./Code/4.1_est_llm_pred_error.py

echo "Generating bills distribution and LLM accuracy plots ..."
Rscript ./Code/4.2_bills_llm_plots.r

echo "Generating LHS results figures and tables..."
Rscript -e "rmarkdown::render('./Code/4.3_lhs_results.rmd', output_dir = './Figures and Tables')"

echo "Generating RHS results figures and tables..."
Rscript -e "rmarkdown::render('./Code/4.4_rhs_results.rmd', output_dir = './Figures and Tables')"

echo "Pipeline completed."