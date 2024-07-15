from openai import OpenAI
from constants import API_KEY
import os
import magic

# testing to confirm the file is jsonl
file_path = 'batch_prompts.jsonl'
if os.path.isfile(file_path):
    file_type = magic.from_file(file_path, mime=True)
    print(f"The file type of '{file_path}' is: {file_type}")

# create client with api
client = OpenAI(api_key=API_KEY)

# this is all copy-pasted from the open ai website
batch_input_file = client.files.create(
  file=open("batch_prompts.jsonl", "rb"),
  purpose="batch"
)

print(batch_input_file)
batch_input_file_id = batch_input_file.id

client.batches.create(
    input_file_id=batch_input_file_id,
    endpoint="/v1/chat/completions",
    completion_window="24h",
    metadata={
      "description": "trial batch (800 inputs)"
    }
)