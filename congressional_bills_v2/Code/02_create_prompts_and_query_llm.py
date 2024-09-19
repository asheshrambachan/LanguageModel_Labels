import os
import pandas as pd
from openai import OpenAI

import numpy as np
import json
from dotenv import load_dotenv

import tiktoken
from copy import deepcopy

# Place API_KEY in the .env file
load_dotenv()
client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))

repo_dir = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills_v2"
os.chdir(repo_dir)

data_dir = os.path.join(repo_dir, "Data")

temp_dir = os.path.join(repo_dir, "Temp")
os.makedirs(temp_dir, exist_ok=True)

os.makedirs(os.path.join(temp_dir, "prompts"), exist_ok=True)

fig_dir = os.path.join(repo_dir, "Figures")
os.makedirs(fig_dir, exist_ok=True)

# Create `prompts.jsonl`
MAJOR_TEXT = pd.read_csv(os.path.join(data_dir, "Codebooks/major_topics.csv")).set_index('Major')['MajorText'].to_dict()

CATEGORIES = "\n".join([f"{int(major)}. {text}" for major, text in MAJOR_TEXT.items()])

QUESTION =f"""Here is a description of a bill introduced in the U.S. Congress:
"{{0}}"

Please classify this description into one of the following categories:
{CATEGORIES}
"""

ANSWER_JSON = f"""Output a JSON object structured like: {{{{
    "Category": an integer from {min(MAJOR_TEXT.keys())} to {max(MAJOR_TEXT.keys())} that best represents the bill category,
    "Confidence": confidence level in the bill classification as a number between 0 to 1 with 2 decimal places
}}}}
"""

ANSWER_JSON_EXPLANATION = f"""Output a JSON object structured like: {{{{
    "Category": an integer from {min(MAJOR_TEXT.keys())} to {max(MAJOR_TEXT.keys())} that best represents the bill category,
    "Confidence": confidence level in the bill classification as a number between 0 to 1 with 2 decimal places,
    "Explanation": a one-sentence explanation for your chosen bill category
}}}}
"""

ANSWER_BLANKS = f"""Write your answer as:
____ (fill in with an integer from {min(MAJOR_TEXT.keys())} to {max(MAJOR_TEXT.keys())} that best represents the bill category),
____ (fill in with confidence level in the bill classification as a number between 0 to 1 with 2 decimal places)
"""

ANSWER_BLANKS_EXPLANATION = f"""Write your answer as:
____ (fill in with an integer from {min(MAJOR_TEXT.keys())} to {max(MAJOR_TEXT.keys())} that best represents the bill category),
____ (fill in with confidence level in the bill classification as a number between 0 to 1 with 2 decimal places),
____ (fill in with a one-sentence explanation for your chosen bill category)
"""

def create_content_user(strategy):
    question = QUESTION + "\n"
    if (not pd.isnull(strategy["TextBefore"])):
        question = strategy["TextBefore"] + question
    
    if (not pd.isnull(strategy["TextAfter"])):
        question = question + strategy["TextAfter"]
        
    if strategy["ResponseFormat"]=="JSON":
        if strategy["AddExplanation"]:
            answer = ANSWER_JSON_EXPLANATION
        else:
            answer = ANSWER_JSON
    else:
        if strategy["AddExplanation"]:
            answer = ANSWER_BLANKS_EXPLANATION
        else:
            answer = ANSWER_BLANKS

    content = question + answer
    return content

def create_content_assistant(strategy, category, confidence, explanation=None):
    if strategy["ResponseFormat"]=="JSON":
        if strategy["AddExplanation"]:

            if explanation is None:
                raise Exception("AddExplanation=True but explanation=None. You need to pass a string to explanation variable")
            
            correct_answer = {
                "Category": category,
                "Confidence": np.round(confidence, decimals=2),
                "Explanation": explanation
            }
        else:
            correct_answer = {
                "Category": category,
                "Confidence": np.round(confidence, decimals=2)
            }
        content = json.dumps(correct_answer)

    else:
        if strategy["AddExplanation"]:

            if explanation is None:
                raise Exception("AddExplanation=True but explanation=None. You need to pass a string to explanation variable")
            
            correct_answer = "%d, %.2f, %s\n" % (category, confidence, explanation)
        else:
            correct_answer = "%d, %.2f\n" % (category, confidence)
        content = correct_answer

    return content

def create_messages(strategy, bills_examples, min_confidence=0.9, max_confidence=1, examples_via_system=True):
    messages = []

    if strategy["AddExamples"]:
        bills_examples = bills_examples[bills_examples["ExampleSetNum"] == strategy["ExampleSetNum"]]
        
        for _, bill in bills_examples.iterrows():
            message_user_content = create_content_user(strategy).format(bill["Description"])

            if examples_via_system:
                message_user = {"role": "system", "name": "example_user", "content": message_user_content}
            else:
                message_user = {"role": "user", "content": message_user_content}
            messages.append(message_user)

            message_assistant_content = create_content_assistant(strategy, category=bill["Major"], confidence=np.random.uniform(min_confidence, max_confidence))
            if examples_via_system:
                message_assistant = {"role": "system", "name": "example_assistant", "content": message_assistant_content}
            else:
                message_assistant = {"role": "assistant", "content": message_assistant_content}
            messages.append(message_assistant)
    
    message_user_content = create_content_user(strategy)
    message_user = {"role": "user", "content": message_user_content}
    messages.append(message_user)
    return messages


prompting_strategies = pd.read_csv(os.path.join(data_dir, "prompting_strategies.csv"))
bills = pd.read_csv(os.path.join(data_dir, f"bills_10k.csv"))
bills_examples = pd.read_csv(os.path.join(data_dir, "bills_examples.csv"))
prompts_path = os.path.join(temp_dir, f"prompts.jsonl")

prompting_strategies_json = []
for _, strategy in prompting_strategies.iterrows():
    strategy_json = {
        "PromptingStrategyID": strategy["PromptingStrategyID"],
        "PromptingStrategyName": strategy["PromptingStrategyName"],
        "ResponseFormat": strategy["ResponseFormat"],
        "AddExplanation": strategy["AddExplanation"],
        "AddExamples": strategy["AddExamples"],
        "Model": strategy["Model"], 
        "Temperature": strategy["Temperature"],
        "Messages": create_messages(strategy, bills_examples, min_confidence=0.9, max_confidence=1, examples_via_system=True)
    }
    prompting_strategies_json.append(strategy_json)
    
prompting_strategies_json = pd.json_normalize(prompting_strategies_json)

id = 0
prompts = []
for _, bill in bills.iterrows():
    for _, strategy in prompting_strategies_json.iterrows():
        
        # add bill to last used message
        bill_messages = deepcopy(strategy["Messages"])
        bill_messages[-1]["content"] = bill_messages[-1]["content"].format(bill["Description"])
        
        id = id + 1
        prompt = {
            "ID": id,
            "BillID": bill["BillID"],
            "PromptingStrategyID": strategy["PromptingStrategyID"],
            "Description": bill["Description"],
            "PromptingStrategyName": strategy["PromptingStrategyName"],
            "ResponseFormat": strategy["ResponseFormat"],
            "AddExplanation": strategy["AddExplanation"],
            "AddExamples": strategy["AddExamples"],
            "Model": strategy["Model"],
            "Temperature": strategy["Temperature"],
            "Major": bill["Major"],
            "MajorText": bill["MajorText"],
            "Messages": bill_messages
        }
        prompts.append(prompt)

with open(prompts_path, "w") as f:
    for prompt in prompts:
        f.write(json.dumps(prompt) + "\n")
print(f"Saved {prompts_path}")

# Estimate Cost using Batch API
INPUT_TOKEN_COST = {
    'gpt-3.5-turbo-0125': 0.25/1e6,
    'gpt-4o-2024-05-13': 2.5/1e6
}

OUTPUT_TOKEN_COST = {
    'gpt-3.5-turbo-0125': 0.75/1e6,
    'gpt-4o-2024-05-13': 7.5/1e6
}

PROMPT2OUTPUT_TOKEN = {
    1: 5.96, 
    2: 19, 
    3: 19, 
    4: 19, 
    5: 19, 
    6: 19, 
    7: 47.56, 
    8: 47.47, 
    9: 48.36, 
    10: 15, 
    11: 15, 
    12: 15
} 

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
    num_tokens += 3  # every reply is primed with <|start|>assistant<|message|>
    return num_tokens

def estimate_cost(prompts):
    prompts = prompts[['PromptingStrategyID', 'Model', 'Messages']]

    input_tokens = []
    for _, prompt in prompts.iterrows():
        num_tokens = count_tokens(prompt['Messages'], prompt['Model'])
        input_tokens = np.append(input_tokens, num_tokens)
    avg_output_tokens = prompts['PromptingStrategyID'].apply(lambda x: PROMPT2OUTPUT_TOKEN[x])

    input_token_cost  = prompts['Model'].apply(lambda x: INPUT_TOKEN_COST[x])
    output_token_cost = prompts['Model'].apply(lambda x: OUTPUT_TOKEN_COST[x])

    input_tokens_cost = input_tokens * input_token_cost
    output_tokens_cost = avg_output_tokens * output_token_cost

    total_cost = (input_tokens_cost + output_tokens_cost).sum()
    return total_cost

prompts = pd.read_json(os.path.join(temp_dir, f'prompts.jsonl'), lines=True)
print(f"Estimated cost of running {os.path.basename(prompts_path)} is ${estimate_cost(prompts):.2f}")

# Create `prompts_batched.jsonl`
prompts_path = os.path.join(temp_dir, f"prompts.jsonl")
prompts = pd.read_json(prompts_path, lines=True)

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
                }
            }
        prompts_batched.append(prompt_batched)

        if ((i==(12e3-1)) | (len(prompts_batched)==50e3) | (i==(len(prompts_model)-1))):
            part = part + 1
            prompts_batched_path = os.path.join(temp_dir, f"prompts/prompts_batched_{model}_part{part}.jsonl")
            with open(prompts_batched_path, "w") as f:
                for prompt_batched in prompts_batched:
                    f.write(json.dumps(prompt_batched) + "\n")
                print(f"Saved {prompts_batched_path}")
            prompts_batched = []

# Generate responses
batches = {}

prompts_batched_paths = glob.glob(os.path.join(temp_dir, f'prompts/prompts_batched_*.jsonl'))

for prompts_batched_path in prompts_batched_paths:
    batch_input_file = client.files.create(
        file = open(prompts_batched_path, "rb"),
        purpose = "batch"
    )
    batch_input_file_id = batch_input_file.id
    batch = client.batches.create(
            input_file_id = batch_input_file_id,
            endpoint = "/v1/chat/completions",
            completion_window = "24h",
            metadata = {"description": f"{os.path.basename(prompts_batched_path)}"}
        )
    
    # Regex pattern to match the part number
    pattern = r'_part(\d+)'

    # Extract the part numbers
    part = int(re.search(pattern, prompts_batched_path).group(1))

    batches[os.path.basename(prompts_batched_path)] = {
        'part': part,
        'id': batch.id
    }

print(batches)
batches = {
    'prompts_batched_gpt-3.5-turbo-0125_part1.jsonl': {'part': 1, 'id': 'batch_tSVIpwOEqYLYIxrzneZ38Cf8'}, #12e3, this was the 1000 bill run, , prompts_batched_1000_gpt-3.5-turbo-0125.json
    'prompts_batched_gpt-3.5-turbo-0125_part2.jsonl': {'part': 2, 'id': 'batch_6yCzX3zUgi7xKFzWx7Y3wCih'}, #50e3, prompts_batched_9000_gpt-3.5-turbo-0125_part1.json
    'prompts_batched_gpt-3.5-turbo-0125_part3.jsonl': {'part': 3, 'id': 'batch_zK9n9beqzKH84y8k45IO4Hep'}, #50e3, prompts_batched_9000_gpt-3.5-turbo-0125_part2.json
    'prompts_batched_gpt-3.5-turbo-0125_part4.jsonl': {'part': 4, 'id': 'batch_pvocTdpKJAeylK6tdHxvpZmu'}, #8e3, prompts_batched_9000_gpt-3.5-turbo-0125_part3.json
    'prompts_batched_gpt-4o-2024-05-13_part1.jsonl':  {'part': 1, 'id': 'batch_Qi4lin1f66j96pho3ofhRxyl'}, #12e3, this was the 1000 bill run, prompts_batched_1000_gpt-4o.json
    'prompts_batched_gpt-4o-2024-05-13_part2.jsonl':  {'part': 2, 'id': 'batch_k0XxH5uZU78uyloLs8IYIBwh'}, #50e3, prompts_batched_9000_gpt-4o_part1.json
    'prompts_batched_gpt-4o-2024-05-13_part3.jsonl':  {'part': 3, 'id': 'batch_0IR9IRoYYJb6TYYvvN8XqXk2'}, #50e3, prompts_batched_9000_gpt-4o_part2.json
    'prompts_batched_gpt-4o-2024-05-13_part4.jsonl':  {'part': 4, 'id': 'batch_8EFmBWRWBFJuStCPbO26rhQ3'}, #8e3, prompts_batched_9000_gpt-4o_part3.json
}