import os
import pandas as pd
import numpy as np
import json
import tiktoken
from datetime import datetime

REPO_DIR = "./headlines_prediction"
PER_BATCH_LIMIT = 50e3 # up to 50,000 requests per batch

# a function to trim a string 
def trim(text, trimprop):
    keepprop = min(1-trimprop, 1)
    return text[:int(len(text) * keepprop)]

def create_prompts(prompt_templates, headlines):
    # headlines["headline"] = headlines["headline"].str.replace('""', r'\"', regex=False)
    # print(headlines.iloc[37797]["headline"])
    id = 0
    prompts = []
    for _, headline in headlines.iterrows():
        for _, template in prompt_templates.iterrows():
            template_path = os.path.join(REPO_DIR, template["template_path"])
            with open(template_path, 'r') as f:
                headline_messages = json.load(f)


            # trim headline description and formate date
            headline_trim = trim(headline["headline"], template["trim_prop"])
            date = datetime.strptime(headline["date"], "%Y-%m-%d").strftime("%-m/%-d/%Y") 
            
            # add headline description
            if (template["add_date"]):
                headline_messages[-1]["content"] = headline_messages[-1]["content"].format(headline["company_name"], date, headline_trim, date)
            else:
                headline_messages[-1]["content"] = headline_messages[-1]["content"].format(headline["company_name"], date, headline_trim)

            id = id + 1
            prompt = {
                "id": id,
                "headline_id": headline["headline_id"],
                "prompt_template_id": template["prompt_template_id"],
                "response_format": template["response_format"],
                "add_date": template["add_date"],
                "model": template["model"],
                "temperature": template["temperature"],
                "max_tokens": template["max_tokens"],
                "headline_trim": headline_trim,
                "messages": headline_messages
            }
            prompts.append(prompt)

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
    prompts = prompts[['prompt_template_id', 'model', 'messages']]

    input_tokens = []
    for _, prompt in prompts.iterrows():
        num_tokens = count_tokens(prompt['messages'], prompt['model'])
        input_tokens = np.append(input_tokens, num_tokens)

    prompt2OutputTokens = {
        1: 20.554518, 
        2: 20.931964
    } 
    avg_output_tokens = prompts['prompt_template_id'].apply(lambda x: prompt2OutputTokens[x])

    # Cost using Batch API
    in_token_cost = {
        'gpt-3.5-turbo-0125': 0.25/1e6,
        'gpt-4o-2024-05-13': 2.5/1e6,
        'gpt-4o-mini-2024-07-18': 0.075/1e6
    }
    out_token_cost = {
        'gpt-3.5-turbo-0125': 0.75/1e6,
        'gpt-4o-2024-05-13': 7.5/1e6,
        'gpt-4o-mini-2024-07-18': 0.300/1e6
    }

    input_token_cost  = prompts['model'].apply(lambda x: in_token_cost[x] if batched else in_token_cost[x]*2)
    output_token_cost = prompts['model'].apply(lambda x: out_token_cost[x] if batched else out_token_cost[x]*2)

    input_tokens_cost = input_tokens * input_token_cost
    output_tokens_cost = avg_output_tokens * output_token_cost

    total_cost = (input_tokens_cost + output_tokens_cost).sum()
    return total_cost

def create_batched_prompts(prompts, batched_prompts_dir):
    batches = []
    for model in prompts["model"].unique(): 
        prompts_model = prompts[prompts["model"]==model].reset_index()

        prompts_batched = []
        part = 0
        for i, prompt in prompts_model.iterrows():
            prompts_batched.append({
                "custom_id": str(prompt["id"]),
                "method": "POST",
                "url": "/v1/chat/completions",
                "body": {
                    "model": prompt["model"],
                    "temperature": prompt["temperature"],
                    "response_format": {"type": "json_object"} if (prompt["response_format"]=="JSON") else None,
                    "messages": prompt["messages"],
                    "max_tokens": prompt["max_tokens"]
                }
            })

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
                
    return(pd.json_normalize(batches))

def main():
    data_dir = os.path.join(REPO_DIR, "Data")
    temp_dir = os.path.join(REPO_DIR, "Temp/LLM")
    batched_prompts_dir = os.path.join(temp_dir, "prompts_batched")
    os.makedirs(temp_dir, exist_ok=True)
    os.makedirs(batched_prompts_dir, exist_ok=True)

    headlines = pd.read_csv(os.path.join(data_dir, "headlines.csv")) 
    prompt_templates = pd.read_csv(os.path.join(data_dir, "prompt_templates.csv"))
    prompt_templates["template_path"] = prompt_templates["template_path"].apply(lambda x: os.path.join(data_dir, x))
    
    # Create `prompts.jsonl`
    prompts_json = create_prompts(prompt_templates, headlines)
    prompts_json_path = os.path.join(temp_dir, "prompts.jsonl")
    with open(prompts_json_path, "w") as f:
        for prompt in prompts_json:
            f.write(json.dumps(prompt) + "\n")
    print(f"Saved {os.path.basename(prompts_json_path)}, n = {len(prompts_json)}, at {os.path.dirname(prompts_json_path)}")
    prompts = pd.json_normalize(prompts_json)
    
    # Create `prompts_batched_*.jsonl`
    batches = create_batched_prompts(prompts, batched_prompts_dir)
    batches_path = os.path.join(temp_dir, "batches.csv")
    batches.to_csv(batches_path, index=False)
    print(f"Created batched prompts with batch details stored at {os.path.basename(batches_path)}, n = {len(batches)}, at {os.path.dirname(batches_path)}")

    # Estimate cost using Batch API
    cost = estimate_cost(prompts, batched=True)
    print(f"Estimated cost using Batch API is ${cost:.2f}")

if __name__ == "__main__":
    main()
