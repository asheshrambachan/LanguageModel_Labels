from openai import OpenAI
from step0_constants import API_KEY

QUESTION = "1"
MONTH = "jan"
YEAR = "19"

file_path = f'./{MONTH}{YEAR}/q{QUESTION}_prompts.jsonl'

# create client with api key
client = OpenAI(api_key=API_KEY)

# this is all copy-pasted from the open ai website
batch_input_file = client.files.create(
  file=open(file_path, "rb"),
  purpose="batch"
)

batch_input_file_id = batch_input_file.id
batch = client.batches.create(
        input_file_id=batch_input_file_id,
        endpoint="/v1/chat/completions",
        completion_window="24h",
        metadata={
        "description": "mar 19 q4"
        }
    )

print(batch)

