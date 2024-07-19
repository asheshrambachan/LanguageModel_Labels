from openai import OpenAI
from step0_constants import API_KEY

# batch dashboard: https://platform.openai.com/batches/

# create client with api key
client = OpenAI(api_key=API_KEY)

# go to the batch dashboard and get the batch string
batch_id = "batch_rR9AfyeOEq6VAUSMnF6j1Zcl"

# check status
batch = client.batches.retrieve(batch_id)

# get response
output_file_id = batch.output_file_id

# uncomment 2 lines this when the status is completed
file_response = client.files.content(output_file_id)
file_response.write_to_file("batch_dec19_output.jsonl")







