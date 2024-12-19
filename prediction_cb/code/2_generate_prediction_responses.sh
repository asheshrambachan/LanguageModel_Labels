#!/bin/bash

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