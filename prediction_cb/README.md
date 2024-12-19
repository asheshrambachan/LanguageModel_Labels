# Prediction Tasks: Congressional Bills

This subdirectory contains scripts, data, and outputs for **prediction tasks** using **Congressional bills** data. The steps involves cleaning and preparing the data, querying LLMs, generating embeddings for similarity analysis, and summarizing the results for use in figures and tables.

## Directory Structure

- `code/`: Python and R scripts for data cleaning, prompt creation, querying LLMs, embedding generation, and result summarization.
- `data/`: Contains input and output data files.
- `temp`/: Temporary directory for intermediate files during execution.

## Replication Options

You can replicate the results using one of the following methods:

1. **Full Replication:** Run the shell script run_all.sh to execute all steps in sequence:
    ```
    chmod +x ./prediction_cb/code/run_all.sh
    ./prediction_cb/code/run_all.sh
    ```

2. **Partial Replication:** Run individual scripts for specific steps. 

    1. Data cleaning
    ```
    python ./prediction_cb/code/1_clean_data.py
    ```

    2. Prompt creation, LLM querying, and response decoding. This step generates prompts for the cleaned data using model and prompt specifications from [prompt_templates.csv](./data/prompt_templates.csv). You can customize these templates in the [prompt_templates/](./data/prompt_templates/) directory.
    ```sh
    chmod +x ./prediction_cb/code/2_generate_prediction_responses.sh
    ./prediction_cb/code/2_generate_prediction_responses.sh
    ```

    3. Embedding generation and similarity analysis:
    ```sh
    chmod +x ./prediction_cb/code/3_embed_prediction_responses.sh
    ./prediction_cb/code/3_embed_prediction_responses.sh
    ```

## Notes

- Final outputs are saved in the `data/` directory as `.csv` files, ready for use in figures and tables.
- Steps that involve querying LLMs (e.g., `2_generate_prediction_responses.sh` and `3_embed_prediction_responses.sh`) can take significant time due to OpenAI response generation. To save time, you can skip these steps and use the pre-generated results provided in the `data/` directory.
- Generated prompts and responses from OpenAI are initially saved in the `temp/` directory. They are later split into smaller files and added to the `data/` directory to be able to upload them to GitHub.
