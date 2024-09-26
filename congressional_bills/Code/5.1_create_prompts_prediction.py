import os
import pandas as pd
import numpy as np
import json
import tiktoken
from datetime import datetime

REPO_DIR = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills"
PER_BATCH_LIMIT = 50e3 # up to 50,000 requests per batch

DEBUG = True
if (DEBUG):
    PER_BATCH_LIMIT = 40

# a function to trim a string 
def trim(text, trimprop):
    keepprop = min(1-trimprop, 1)
    return text[:int(len(text) * keepprop)]

def create_prompts(prompting_strategies, bills):
    id = 0
    prompts = []
    for _, bill in bills.iterrows():
        for _, strategy in prompting_strategies.iterrows():
            
            template_path = os.path.join(REPO_DIR, strategy["TemplatePath"])
            with open(template_path, 'r') as template:
                bill_messages = json.load(template)

            bill_id = bill["BillID"]
            bill_description = bill["Description"]

            # trim bill description
            if (strategy["TrimText"]):
                bill_description = trim(bill_description, strategy["TrimProp"])

            # add bill description 
            if (strategy["AddIntrYear"]):
                bill_date = datetime.strptime(bill['IntrDate'], "%Y-%m-%d").strftime('%-m/%-d/%Y')
                bill_messages[-1]["content"] = bill_messages[-1]["content"].format(bill_id, bill_description, bill_date)
            else:
                bill_messages[-1]["content"] = bill_messages[-1]["content"].format(bill_id, bill_description)

            id = id + 1
            prompt = {
                "ID": id,
                "BillID": bill["BillID"],
                "PromptingStrategyID": strategy["PromptingStrategyID"],
                "PromptingStrategyName": strategy["PromptingStrategyName"],
                "ResponseFormat": strategy["ResponseFormat"],
                "TrimText": strategy["TrimText"],
                "AddIntrYear": strategy["AddIntrYear"],
                "Model": strategy["Model"],
                "Temperature": strategy["Temperature"],
                "MaxTokens": strategy["MaxTokens"],
                "Messages": bill_messages
            }
            prompts.append(prompt)

            # print(bill_messages[-1]["content"])

    return(prompts)

def count_tokens(messages, model):
    encoding = tiktoken.encoding_for_model(model)
    tokens_per_message = 3
    tokens_per_name = 1
    num_tokens = 0
    for message in messages:
        num_tokens += tokens_per_message
        for key, value in message.items():
            num_tokens += len(encoding.encode(value))
            if key == "name":
                num_tokens += tokens_per_name
    num_tokens += 3 
    return num_tokens

def estimate_cost(prompts, batched=True):
    prompts = prompts[['PromptingStrategyID', 'Model', 'Messages']]

    input_tokens = []
    for _, prompt in prompts.iterrows():
        num_tokens = count_tokens(prompt['Messages'], prompt['Model'])
        input_tokens = np.append(input_tokens, num_tokens)

    # TODO: correct based on test run
    prompt2OutputTokens = {
        1: 22, 
        2: 22, 
        3: 75.5, 
        4: 47.0
    } 
    avg_output_tokens = prompts['PromptingStrategyID'].apply(lambda x: prompt2OutputTokens[x])

    # Cost using Batch API
    in_token_cost = {
        'gpt-3.5-turbo-0125': 0.25/1e6,
        'gpt-4o-2024-05-13': 2.5/1e6
    }
    out_token_cost = {
        'gpt-3.5-turbo-0125': 0.75/1e6,
        'gpt-4o-2024-05-13': 7.5/1e6
    }

    input_token_cost  = prompts['Model'].apply(lambda x: in_token_cost[x] if batched else in_token_cost[x]*2)
    output_token_cost = prompts['Model'].apply(lambda x: out_token_cost[x] if batched else out_token_cost[x]*2)

    input_tokens_cost = input_tokens * input_token_cost
    output_tokens_cost = avg_output_tokens * output_token_cost

    total_cost = (input_tokens_cost + output_tokens_cost).sum()
    return total_cost

def create_batched_prompts(prompts, batched_prompts_dir):
    batches = []
    for model in prompts["Model"].unique(): 
        prompts_model = prompts[prompts["Model"]==model].reset_index()

        prompts_batched = []
        part = 0
        for i, prompt in prompts_model.iterrows():
            prompt_batched = {
                    "custom_id": "ID_" + str(prompt["ID"]),
                    "method": "POST",
                    "url": "/v1/chat/completions",
                    "body": {
                        "model": prompt["Model"],
                        "temperature": prompt["Temperature"],
                        "response_format": {"type": "json_object"} if (prompt["ResponseFormat"]=="JSON") else None,
                        "messages": prompt["Messages"],
                        "max_tokens": prompt["MaxTokens"] if (prompt["PromptingStrategyName"]=="Complete Bill Summary") else None
                    }
                }
            prompts_batched.append(prompt_batched)

            if ((len(prompts_batched)==PER_BATCH_LIMIT) | (i==(len(prompts_model)-1))):
                part = part + 1
                prompts_batched_path = os.path.join(batched_prompts_dir, f"prompts_batched_{model}_part{part}.jsonl")

                with open(prompts_batched_path, "w") as f:
                    for prompt_batched in prompts_batched:
                        f.write(json.dumps(prompt_batched) + "\n")
                    print(f"Saved {os.path.basename(prompts_batched_path)}, n = {len(prompts_batched)}, at {os.path.dirname(prompts_batched_path)}")
                prompts_batched = []

                batch = {
                    'file': prompts_batched_path,
                    'part': part,
                    'model': model
                }
                batches.append(batch)
                
                if (DEBUG):
                    break
    return(pd.json_normalize(batches))

def main():
    data_dir = os.path.join(REPO_DIR, "Data")
    temp_dir = os.path.join(REPO_DIR, "Temp")
    
    batched_prompts_dir = os.path.join(temp_dir, "prompts_batched_prediction")
    os.makedirs(temp_dir, exist_ok=True)
    os.makedirs(batched_prompts_dir, exist_ok=True)

    bills = pd.read_csv(os.path.join(data_dir, "bills_prediction.csv"))
    prompting_strategies = pd.read_csv(os.path.join(data_dir, "prompt_templates_prediction.csv"))
    
    # Create `prompts.jsonl`
    prompts_json = create_prompts(prompting_strategies, bills)
    prompts_json_path = os.path.join(temp_dir, "prompts_prediction.jsonl")
    with open(prompts_json_path, "w") as f:
        for prompt in prompts_json:
            f.write(json.dumps(prompt) + "\n")
    print(f"Saved {os.path.basename(prompts_json_path)}, n = {len(prompts_json)}, at {os.path.dirname(prompts_json_path)}")
    prompts = pd.json_normalize(prompts_json)
    
    # Create `prompts_batched_*.jsonl`
    batches = create_batched_prompts(prompts, batched_prompts_dir)
    batches_path = os.path.join(temp_dir, "batches_prediction.csv")
    batches.to_csv(batches_path, index=False)
    print(f"Created batched prompts with batch details stored at {os.path.basename(batches_path)}, n = {len(batches)}, at {os.path.dirname(batches_path)}")

    # Estimate cost using Batch API
    cost = estimate_cost(prompts, batched=True)
    print(f"Estimated cost using Batch API is ${cost:.2f}")

if __name__ == "__main__":
    main()
