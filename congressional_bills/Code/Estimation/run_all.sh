#!/bin/bash

# Step 0: Data Cleaning
echo "Starting data cleaning..."
python ./Code/clean_bills.py

# Step 1: Prompt Creation, Querying and Decoding LLM Responses
echo "Creating prompts..."
python ./Code/Estimation/1.1_create_prompts.py

echo "Querying LLMs..."
python ./Code/Estimation/1.2_query_llm.py

echo "Downloading LLM responses..."
python ./Code/Estimation/1.3_download_responses.py

echo "Decoding LLM responses..."
python ./Code/Estimation/1.4_decode_responses.py

# Step 2: Simulation Runs & Model Evaluation
echo "Running LHS simulations..."
Rscript ./Code/Estimation/2.1.1_run_lhs_simulations.r

echo "Summarizing LHS simulations..."
Rscript ./Code/Estimation/2.1.2_summarize_lhs_simulations.r

echo "Running RHS simulations..."
Rscript ./Code/Estimation/2.2.1_run_rhs_simulations.r

echo "Summarizing RHS simulations..."
Rscript ./Code/Estimation/2.2.2_summarize_rhs_simulations.r

# Step 3: Figure and Table Generation
echo "Estimating LLM prediction errors..."
python ./Code/Estimation/3.1_est_llm_pred_error.py

echo "Generating bills distribution and LLM accuracy plots..."
Rscript ./Code/Estimation/3.2_bills_llm_plots.r

echo "Generating figures and tables..."
Rscript ./Code/Estimation/3.3_figures_tables.r

echo "Pipeline completed."