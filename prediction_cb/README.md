# Prediction Tasks: Congressional Bills

This subdirectory contains scripts, data, and outputs for **prediction tasks** using **Congressional bills** data. The steps involves cleaning and preparing the data, querying LLMs, generating embeddings for similarity analysis, and summarizing the results for use in figures and tables.

## Directory Structure

- `code/`: Python and R scripts for data cleaning, prompt creation, querying LLMs, embedding generation, and result summarization.
- `data/`: Contains input and output data files.
- `temp/`: Temporary directory for intermediate files during execution.

## Replication Options

You can replicate the results using one of the following methods:

1. **Full Replication:** Run the shell script run_all.sh to execute all steps in sequence:
    ```
    chmod +x ./prediction_cb/code/run_all.sh
    ./prediction_cb/code/run_all.sh
    ```

2. **Partial Replication:** Run individual scripts for specific steps. 

    1. Data cleaning.
        ```
        python ./prediction_cb/code/1_clean_data.py
        ```

    2. Prompt creation, LLM querying, and response decoding. 
        ```sh
        python ./prediction_cb/code/2.1_create_prompts.py
        python ./prediction_cb/code/2.2_query_llm.py
        python ./prediction_cb/code/2.3_download_responses.py
        python ./prediction_cb/code/2.4_decode_responses.py
        Rscript ./prediction_cb/code/2.5_summarize_prediction.R
        ```

    3. Embedding generation and similarity analysis:
        ```sh
        python ./prediction_cb/code/3.1_create_embed_prompts.py
        python ./prediction_cb/code/3.2_query_embed_prompts.py
        python ./prediction_cb/code/3.3_download_embed_responses.py
        python ./prediction_cb/code/3.4_decode_embed_responses.py
        Rscript ./prediction_cb/code/3.5_summarize_completion.R
        ```

## Notes
- Step `2.1` generates prompts for the cleaned data using model and prompt specifications from [prompt_templates.csv](./data/prompt_templates.csv). You can customize these templates in the [prompt_templates/](./data/prompt_templates/) directory. 
- In steps `2.1` and `3.1`, the OpenAI API token limit varies by user. If needed, you can split the prompts into smaller batches by modifying the `PER_BATCH_LIMIT` constant in the beginning of the script.
- Steps that involve querying LLMs (i.e., `2.2`, `2.3`, `3.2`, and `3.3`) can take significant time due to OpenAI response generation. To save time, you can skip these steps and use the pre-generated results provided in the `data/` directory.
- Data generated is initially saved in the `temp/` directory. It is then split into smaller files and added to the `data/` directory to facilitate GitHub uploads and enable replication of subsequent steps.
- Final outputs are saved in the `data/` directory as `.csv` files, ready for use in figures and tables.
