#!/bin/bash

# Step 1: Data Cleaning
echo "Starting data cleaning..."
python ./prediction_cb/code/1_clean_data.py

# Step 2: Prompt Creation, Querying and Decoding LLM Responses
chmod +x ./prediction_cb/code/2_generate_prediction_responses.sh
./prediction_cb/code/2_generate_prediction_responses.sh

# Step 3: Embedding generation and similarity analysis
chmod +x ./prediction_cb/code/3_embed_prediction_responses.sh
./prediction_cb/code/3_embed_prediction_responses.sh
