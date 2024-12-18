#!/bin/bash

# Step 1: Data Cleaning
echo "Starting data cleaning..."
python ./prediction_cb/code/1_clean_bills.py

# Step 2: Prompt Creation, Querying and Decoding LLM Responses
echo "Creating prompts..."
python ./prediction_cb/code/2.1_create_prompts.py

echo "Querying LLMs..."
python ./prediction_cb/code/2.2_query_llm.py

echo "Downloading LLM responses..."
python ./prediction_cb/code/2.3_download_responses.py

echo "Decoding LLM responses..."
python ./prediction_cb/code/2.4_decode_responses.py

# Step 3: Embed Completion Responses
echo "Creating embedding prompts..."
python ./prediction_cb/code/3.1_create_embed_prompts.py

echo "Querying LLMs..."
python ./prediction_cb/code/3.2_query_embed_llm.py

echo "Downloading responses for embedding prompts..."
python ./prediction_cb/code/3.3_download_embed_responses.py

echo "Decoding responses and compute similarity between embeddings..."
python ./prediction_cb/code/3.4_decode_embed_responses.py

# Step 4: Summarize Results
echo "Summarize prediction results..."
Rscript ./prediction_cb/code/4.1_summarize_prediction.R

echo "Summarize completion results..."
Rscript ./prediction_cb/code/4.2_summarize_completion.R
