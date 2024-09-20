import os
import pandas as pd
from openai import OpenAI
import numpy as np
import json
from dotenv import load_dotenv
import re
import tiktoken
from copy import deepcopy

# Place API_KEY in the .env file
load_dotenv()
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY')
REPO_DIR = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills_v2"

MAJOR_TEXT = {
    1: "Macroeconomics",
    2: "Civil Rights, Minority Issues, and Civil Liberties",
    3: "Health",
    4: "Agriculture",
    5: "Labor and Employment",
    6: "Education",
    7: "Environment",
    8: "Energy",
    9: "Immigration",
    10: "Transportation",
    11: "Law, Crime, and Family Issues",
    12: "Social Welfare",
    13: "Community Development and Housing Issues",
    14: "Banking, Finance, and Domestic Commerce",
    15: "Defense",
    16: "Space, Science, Technology, and Communications",
    17: "Foreign Trade",
    18: "International Affairs and Foreign Aid",
    19: "Government Operations",
    20: "Public Lands and Water Management"
}

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



def create_prompts(prompting_strategies, bills, bills_examples):
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
                # "Description": bill["Description"],
                "PromptingStrategyName": strategy["PromptingStrategyName"],
                "ResponseFormat": strategy["ResponseFormat"],
                "AddExplanation": strategy["AddExplanation"],
                "AddExamples": strategy["AddExamples"],
                "Model": strategy["Model"],
                "Temperature": strategy["Temperature"],
                # "Major": bill["Major"],
                # "MajorText": bill["MajorText"],
                "Messages": bill_messages
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
    num_tokens += 3  # every reply is primed with <|start|>assistant<|message|>
    return num_tokens

def estimate_cost(prompts, batched=True):
    prompts = prompts[['PromptingStrategyID', 'Model', 'Messages']]

    input_tokens = []
    for _, prompt in prompts.iterrows():
        num_tokens = count_tokens(prompt['Messages'], prompt['Model'])
        input_tokens = np.append(input_tokens, num_tokens)

    prompt2OutputTokens = {
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
                    }
                }
            prompts_batched.append(prompt_batched)

            if ((i==(12e3-1)) | (len(prompts_batched)==50e3) | (i==(len(prompts_model)-1))):
                part = part + 1
                prompts_batched_path = os.path.join(batched_prompts_dir, f"prompts_batched_{model}_part{part}.jsonl")

                with open(prompts_batched_path, "w") as f:
                    for prompt_batched in prompts_batched:
                        f.write(json.dumps(prompt_batched) + "\n")
                    print(f"Saved {os.path.basename(prompts_batched_path)}, n = {len(prompts_batched)}, at {os.path.dirname(prompts_batched_path)}")
                prompts_batched = []

                batch = {
                    'file': prompts_batched_path,
                    'part': part
                }
                batches.append(batch)

    return(pd.json_normalize(batches))

def query_llm(batches):
    client = OpenAI(api_key=OPENAI_API_KEY)
    
    batches_id = []
    for _, batch in batches.iterrows():
        batch_input_file = client.files.create(
            file = open(batch['file'], "rb"),
            purpose = "batch"
        )

        new_batch = client.batches.create(
            input_file_id = batch_input_file.id,
            endpoint = "/v1/chat/completions",
            completion_window = "24h",
            metadata = {"description": f"{os.path.basename(batch['file'])}"}
        )

        batches_id.append(new_batch.id)
    
    batches['id'] = batches_id
    return(batches)

def main():
    data_dir = os.path.join(REPO_DIR, "Data")
    temp_dir = os.path.join(REPO_DIR, "Temp")
    batched_prompts_dir = os.path.join(temp_dir, "prompts_batched")
    os.makedirs(temp_dir, exist_ok=True)
    os.makedirs(batched_prompts_dir, exist_ok=True)

    prompting_strategies = pd.read_csv(os.path.join(data_dir, "prompting_strategies.csv"))
    bills = pd.read_csv(os.path.join(data_dir, "bills_10k.csv"))
    bills_examples = pd.read_csv(os.path.join(data_dir, "bills_examples.csv"))

    # Create `prompts.jsonl`
    prompts_json = create_prompts(prompting_strategies, bills, bills_examples)
    with open(os.path.join(temp_dir, "prompts.jsonl"), "w") as f:
        for prompt in prompts_json:
            f.write(json.dumps(prompt) + "\n")
    print(f"Saved prompts.jsonl, n = {len(prompts_json)}, at {temp_dir}")
    prompts = pd.json_normalize(prompts_json)

    # Estimate cost using Batch API
    cost = estimate_cost(prompts, batched=True)
    print(f"Estimated cost using Batch API is ${cost:.2f}")

    # Create `prompts_batched.jsonl`
    batches = create_batched_prompts(prompts, batched_prompts_dir)

    # Query LLM and store batches id 
    batches = query_llm(batches)
    batches.to_csv(os.path.join(data_dir, "batches.csv"), index=False)
    print(f"Saved batches.csv, n = {len(batches)}, at {data_dir}")

if __name__ == "__main__":
    main()
