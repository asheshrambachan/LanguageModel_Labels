# Prediction Tasks: Financial News Headlines

This subdirectory contains scripts, data, and outputs for **prediction tasks** using **financial news headlines** data. The steps involves cleaning and preparing the data, querying LLMs, generating embeddings for similarity analysis, and summarizing the results for use in figures and tables.

## Directory Structure

- `code/`: Python and R scripts for data cleaning, prompt creation, querying LLMs, embedding generation, and result summarization.
- `data/`: Contains input and output data files.
- `temp`/: Temporary directory for intermediate files during execution.

## Replication Options

You can replicate the results using one of the following methods:

1. **Full Replication:** Run the shell script run_all.sh to execute all steps in sequence:
    ```
    chmod +x ./prediction_headlines/code/run_all.sh
    ./prediction_headlines/code/run_all.sh
    ```

2. **Partial Replication:** Run individual scripts for specific steps. 

    1. Data cleaning
        ```
        python ./prediction_headlines/code/1_clean_data.py
        ```

    2. Prompt creation, LLM querying, and response decoding. 
    
        - This step generates prompts for the cleaned data using model and prompt specifications from [prompt_templates.csv](./data/prompt_templates.csv). You can customize these templates in the [prompt_templates/](./data/prompt_templates/) directory.
        - Steps that involve querying LLMs (i.e., `2.2_query_llm.py` and `2.3_download_responses.py`) can take significant time due to OpenAI response generation. To save time, you can skip them and use the pre-generated results provided in the `data/` directory.

        ```sh
        python ./prediction_headlines/code/2.1_create_prompts.py
        python ./prediction_headlines/code/2.2_query_llm.py
        python ./prediction_headlines/code/2.3_download_responses.py
        python ./prediction_headlines/code/2.4_decode_responses.py
        ```

    3. Embedding generation and similarity analysis. 

        Note: Steps that involve querying LLMs (i.e., `3.2_query_embed_prompts.py` and `3.3_download_embed_responses.py`) can take significant time due to OpenAI response generation. To save time, you can skip them and use the pre-generated results provided in the `data/` directory.

        ```sh
        python ./prediction_headlines/code/3.1_create_embed_prompts.py
        python ./prediction_headlines/code/3.2_query_embed_prompts.py
        python ./prediction_headlines/code/3.3_download_embed_responses.py
        python ./prediction_headlines/code/3.4_decode_embed_responses.py
        Rscript ./prediction_headlines/code/3.5_summarize_completion.R
        ```

## Notes

- Final outputs are saved in the `data/` directory as `.csv` files, ready for use in figures and tables.
- Generated prompts and responses from OpenAI are initially saved in the `temp/` directory. They are later split into smaller files and added to the `data/` directory to be able to upload them to GitHub.
