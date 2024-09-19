import os
import pandas as pd
from openai import OpenAI
from dotenv import load_dotenv

temp_dir = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills_v2/Temp"

# Place API_KEY in the .env file
load_dotenv()
client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))

batches = {
    'prompts_batched_gpt-3.5-turbo-0125_part1.jsonl': {'part': 1, 'id': 'batch_tSVIpwOEqYLYIxrzneZ38Cf8'}, #12e3, this was the 1000 bill run, , prompts_batched_1000_gpt-3.5-turbo-0125.json
    'prompts_batched_gpt-3.5-turbo-0125_part2.jsonl': {'part': 2, 'id': 'batch_6yCzX3zUgi7xKFzWx7Y3wCih'}, #50e3, prompts_batched_9000_gpt-3.5-turbo-0125_part1.json
    'prompts_batched_gpt-3.5-turbo-0125_part3.jsonl': {'part': 3, 'id': 'batch_zK9n9beqzKH84y8k45IO4Hep'}, #50e3, prompts_batched_9000_gpt-3.5-turbo-0125_part2.json
    'prompts_batched_gpt-3.5-turbo-0125_part4.jsonl': {'part': 4, 'id': 'batch_pvocTdpKJAeylK6tdHxvpZmu'}, #8e3, prompts_batched_9000_gpt-3.5-turbo-0125_part3.json
    'prompts_batched_gpt-4o-2024-05-13_part1.jsonl':  {'part': 1, 'id': 'batch_Qi4lin1f66j96pho3ofhRxyl'}, #12e3, this was the 1000 bill run, prompts_batched_1000_gpt-4o.json
    'prompts_batched_gpt-4o-2024-05-13_part2.jsonl':  {'part': 2, 'id': 'batch_k0XxH5uZU78uyloLs8IYIBwh'}, #50e3, prompts_batched_9000_gpt-4o_part1.json
    'prompts_batched_gpt-4o-2024-05-13_part3.jsonl':  {'part': 3, 'id': 'batch_0IR9IRoYYJb6TYYvvN8XqXk2'}, #50e3, prompts_batched_9000_gpt-4o_part2.json
    'prompts_batched_gpt-4o-2024-05-13_part4.jsonl':  {'part': 4, 'id': 'batch_8EFmBWRWBFJuStCPbO26rhQ3'} #8e3, prompts_batched_9000_gpt-4o_part3.json
}

# Check status of all batches
for file in batches:
    id = batches[file]['id']
    batch_status = client.batches.retrieve(id)
    print(f"{file:>52s}: {batch_status.status}")

for file in batches:
    batch_id = batches[file]['id']
    part = batches[file]['part']
    batch_status = client.batches.retrieve(batch_id)
    
    if batch_status.status != "completed":
        print(f"Skipping incomplete file = {file}, Batch ID = {batch_id}")
        continue
    
    output_file_id = batch_status.output_file_id
    responses_batched = client.files.content(output_file_id)

    responses_batched_path = os.path.join(temp_dir, file.replace("prompts", "responses"))
    responses_batched.write_to_file(responses_batched_path)

    # if not part 1, we correct the ID as it shouldn't start from 1
    if (part!=1):
        responses_batched = pd.read_json(responses_batched_path, lines=True)
        responses_batched["custom_id"] = responses_batched["custom_id"].apply(lambda x: "ID_" + str(int(x[3:]) + int(1000*24))) 
        responses_batched.to_json(responses_batched_path, orient='records', lines=True)

    print(f"Saved raw responses at {responses_batched_path}")
