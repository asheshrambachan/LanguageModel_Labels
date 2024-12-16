# Prediction Task: Congressional Bills

This subdirectory contains the code and data required to perform prediction tasks for Congressional Bills as described in the paper "[Large Language Models: An Applied Econometric Framework](https://arxiv.org/pdf/2412.07031)". 

## Directory Structure
```
prediction_cb/
├── Code/              # Code for data cleaning, prompt creation, querying, response decoding, and analysis.
├── Date/              # Contains Congressional Bills data, LLM responses, similarity computations and benchmark data.
├── Temp/              # Generated embeddings and associated metadata.
└── README.md          # Documentation for this subdirectory.
```

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
    - **3.2** Queries the `text-embedding-3-small` embedding model with a default embedding size of `1536`.
    - **3.3** Downloads embedding responses.
    - **3.4** Compute Cosine similarity and Euclidean distance between embeddings + random benchmark using true completion embeddings.
