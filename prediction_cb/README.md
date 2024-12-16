- **Prediction:**
    1. **Data Cleaning:** Downloads and cleans the congressional bills data, creating a sample of 10,000 bills with unique description and no missing introduction date.
    2. **Prompt Creation, LLM Querying, and Response Decoding**
        - **2.1** Generates 8 prompts per bill using 4 prompt templates and 2 models.
        - **2.2** Queries LLM models.
        - **2.3** Downloads LLM responses.
        - **2.4** Decodes LLM responses and merge with metadata.
    3. **Encode completion responses and compute similarity scores**

# Bill Passage

- **Number of observations:** 40,000. 

# Bill Summary Completion

- **Number of Observations:** 40,000, with 39 responses exceeding the 750-token limit.

- **Cleaning:** For responses missing the provided part of the bill summary, we append it. If a response starts differently from the provided summary, we leave it as is. Both the true and LLM summaries are cleaned by removing **non-alphanumeric** characters and converting everything to lowercase.

- **Embedding Model:** Cleaned summaries are embedded using OpenAI’s `text-embedding-3-small` model, with an embedding size of 1536.
