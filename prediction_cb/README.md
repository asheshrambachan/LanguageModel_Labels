# Prediction Tasks: Congressional Bills

This subdirectory contains scripts, data, and outputs for **prediction tasks** using **Congressional bills** data. The workflow involves cleaning and preparing the data, querying LLMs, generating embeddings for similarity analysis, and summarizing the results for use in plots and tables.

## Directory Structure
- `code/`: Python and R scripts for data cleaning, prompt creation, querying LLMs, embedding generation, and result summarization.
    - `1_clean_bills.py`: Cleans and preprocesses Congressional Bills data.
    - `2.*.py`: Scripts for prompt creation, LLM querying, and response decoding using the specified prompt templates and LLM models (see [here](./data/prompt_templates.csv)).
    - `3.*.py`: Scripts for embedding generation and similarity analysis.
    - `4.*.py`: Scripts for summarizing prediction and completion results.
    - `run_all.sh`: Shell script to execute the entire workflow in sequence.
- `data/`: Contains input and output data files, including:
- `temp`/: Temporary directory for intermediate files during execution.

## Replication Options

You can replicate the workflow using the following methods:
1. **Full Replication:** Run the shell script run_all.sh to execute all steps in sequence:
    ```
    chmod +x ./prediction_cb/code/run_all.sh
    ./prediction_cb/code/run_all.sh
    ```

2. **Partial Replication:** Run individual scripts for specific steps.

    1. Data cleaning
    ```
    python ./prediction_cb/code/1_clean_bills.py
    ```

    2. Run prediction prompts
        - Prompt creation:
        ```sh
        python ./prediction_cb/code/2.1_create_prompts.py
        ```
        - Querying LLMs:
        ```sh
        python ./prediction_cb/code/2.2_query_llm.py
        ```
        - Downloading LLM responses: 
        ```sh
        python ./prediction_cb/code/2.3_download_responses.py
        ```
        - Decoding LLM responses:
        ```sh
        python ./prediction_cb/code/2.4_decode_responses.py
        ```
    3. Generate embeddings of LLM responses
        - Create embedding prompts:
        ```sh
        python ./prediction_cb/code/3.1_create_embed_prompts.py
        ```
        - Query `text-embedding-3-small` model:
        ```sh
        python ./prediction_cb/code/3.2_query_embed_llm.py
        ```
        - Download embedding results:
        ```sh
        python ./prediction_cb/code/3.3_download_embed_responses.py
        ```
        - Decode responses and perform similarity analysis:
        ```sh
        python ./prediction_cb/code/3.4_decode_embed_responses.py
        ```
    4. Summarize results
    ```sh
    Rscript ./prediction_cb/code/4.1_summarize_prediction.R
    Rscript ./prediction_cb/code/4.2_summarize_completion.R
    ```

<!-- 
## Usage Instructions
The code are labeled by their order in the workflow.
1. **Data Cleaning:** Downloads and cleans data. Creates a sample of 10,000 bills with unique descriptions, and no missing introduction dates.
2. **Prompt Creation, LLM Querying, and Response Decoding:**
    - **2.1** Generates 8 prompts per bill using 4 prompt templates and 2 LLM models.
    - **2.2** Queries LLM models with generated prompts.
    - **2.3** Downloads responses from the LLM models.
    - **2.4** Decodes LLM responses and merges them with metadata.
3. **Embedding for Similarity Analysis**
    - **3.1** Generates embeddings for Original bill and LLM-completed summaries. Note: We append the provided part of the bill summary if missing, and leaving responses unchanged if they start differently from the provided summary. We also removing non-alphanumeric characters, and converting all text to lowercase prior to generating the embeddings.
    - **3.2** Queries the embedding model with a default embedding size of `1536`.
    - **3.3** Downloads embedding responses.
    - **3.4** Compute Cosine similarity and Euclidean distance between embeddings + random benchmark using true completion embeddings. -->
