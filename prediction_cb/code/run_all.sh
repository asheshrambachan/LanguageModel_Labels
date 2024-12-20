#!/bin/bash

# Step 1: Data Cleaning
echo "Starting data cleaning..."
python ./prediction_cb/code/1_clean_data.py

# Step 2: Prediction Prompt Creation, Querying and Decoding LLM Responses
echo "Creating prompts..."
python ./prediction_cb/code/2.1_create_prompts.py

echo "Querying LLMs..."
python ./prediction_cb/code/2.2_query_llm.py

echo "Downloading LLM responses..."
python ./prediction_cb/code/2.3_download_responses.py

echo "Decoding LLM responses..."
python ./prediction_cb/code/2.4_decode_responses.py

echo "Summarize prediction results..."
Rscript ./prediction_cb/code/2.5_summarize_prediction.R

# Step 3: Embedding prediction responses and perform similarity analysis
echo "Create embedding prompts..."
python ./prediction_cb/code/3.1_create_embed_prompts.py

echo "Query text-embedding-3-small model using  default embedding size of 1536..."
python ./prediction_cb/code/3.2_query_embed_prompts.py

echo "Download embedding results..."
python ./prediction_cb/code/3.3_download_embed_responses.py

echo "Decode responses and perform similarity analysis..."
python ./prediction_cb/code/3.4_decode_embed_responses.py

echo "Summarize completion results..."
Rscript ./prediction_cb/code/3.5_summarize_completion.R
