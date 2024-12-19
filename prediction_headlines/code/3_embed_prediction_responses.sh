#!/bin/bash

# Step 3: Embedding prediction responses and perform similarity analysis
echo "Create embedding prompts..."
python ./prediction_headlines/code/3.1_create_embed_prompts.py

echo "Query text-embedding-3-small model using  default embedding size of 1536..."
python ./prediction_headlines/code/3.2_query_embed_prompts.py

echo "Download embedding results..."
python ./prediction_headlines/code/3.3_download_embed_responses.py

echo "Decode responses and perform similarity analysis..."
python ./prediction_headlines/code/3.4_decode_embed_responses.py

echo "Summarize completion results..."
Rscript ./prediction_headlines/code/3.5_summarize_completion.R
