#!/bin/bash

# Step 1: Data Cleaning
echo "Starting data cleaning..."
python ./estimation_legislation/code/1_clean_bills.py

# Step 2: Prompt Creation, Querying and Decoding LLM Responses
echo "Creating prompts..."
python ./estimation_legislation/code/2.1_create_prompts.py

echo "Querying LLMs..."
python ./estimation_legislation/code/2.2_query_llm.py

echo "Downloading LLM responses..."
python ./estimation_legislation/code/2.3_download_responses.py

echo "Decoding LLM responses..."
python ./estimation_legislation/code/2.4_decode_responses.py

# Step 3: Simulation Runs & Model Evaluation
echo "Running LHS simulations..."
Rscript ./estimation_legislation/code/3.1_run_lhs_simulations.r

echo "Running RHS simulations..."
Rscript ./estimation_legislation/code/3.2_run_rhs_simulations.r

echo "Summarizing LHS simulations..."
Rscript ./estimation_legislation/code/3.3_summarize_lhs_simulations.r

echo "Summarizing RHS simulations..."
Rscript ./estimation_legislation/code/3.4_summarize_rhs_simulations.r

# echo "Estimating LLM prediction errors..."
# python ./estimation_legislation/code/est_llm_pred_error.py