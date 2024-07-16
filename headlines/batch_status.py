from openai import OpenAI
from constants import API_KEY

# create client with api key
client = OpenAI(api_key=API_KEY)

# check status
# print(client.batches.retrieve("batch_cHZ6yLmpOhrFbPvXY1SO21F6"))

# get response
file_response = client.files.content("file-dZSiCLjchsdA5gq89aVr5qDk")
print(dir(file_response))

file_response.write_to_file("batch_output.jsonl")







