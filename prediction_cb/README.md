
# Bill Passage

- **Number of observations:** 40,000. 

# Bill Summary Completion

- **Number of Observations:** 40,000, with 39 responses exceeding the 750-token limit.

- **Cleaning:** For responses missing the provided part of the bill summary, we append it. If a response starts differently from the provided summary, we leave it as is. Both the true and LLM summaries are cleaned by removing **non-alphanumeric** characters and converting everything to lowercase.

- **Embedding Model:** Cleaned summaries are embedded using OpenAI’s `text-embedding-3-small` model, with an embedding size of 1536.
