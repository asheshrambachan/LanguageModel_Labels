import os
import pandas as pd
from tqdm import tqdm
import json
from s0_constants import personas, thought_modifiers, explanation, explanation_json, models, month_batches, years, economic_questions

def format_content(content, JSON=False, chain_of_thought=False):
    """
    Formats the prompt based on strategy.
    
    Parameters:
    - content (str): The prompt to send to the model.
    - JSON (bool): Whether the format should be JSON or not.
    - chain_of_thought (bool): Whether to include chain of thought explanation in the prompt.

    Returns:
    - response_text (str): The response from the model.
    """
    if chain_of_thought:
        content = content[:-1] + (explanation_json if JSON else explanation)
    
    return content

def read_base_prompt(base_prompt_file, suffix):
    """
    Reads the base prompt from a file.
    
    Parameters:
    - base_prompt_file (str): The base file path for the prompt.
    - suffix (str): The suffix to determine the file name.

    Returns:
    - content (str): The content of the base prompt file.
    """
    with open(base_prompt_file + suffix + '.txt', 'r') as file:
        content = file.read()
    return content

def write_prompt(companies, content, JSON, file, id_num, model):
    """
    Generates responses for each company in the dataframe.
    
    Parameters:
    - companies (DataFrame): DataFrame containing company information.
    - content (str): The base content for the prompt.
    - JSON (bool): Whether to include JSON in the responses.
    - file: The file path where batch prompts will be written.
    - id_num (int): Identifier number for the prompts.
    - model (str): The model to use for generating prompts.

    Returns:
    - id_num (int): The updated identifier number.
    """
    all_prompts = []

    for index, row in tqdm(companies.iterrows(), total=companies.shape[0]):
        company = row["company_name"]
        headline = row["headline"]

        company_content = content % (company, headline, company)

        if JSON:
            base_json = company_content
            personas_json = [persona + company_content for persona in personas]

            pt1, pt2 = company_content.split("Write", 1)
            pt2 = "Write" + pt2
            thought_json = [format_content(pt1 + thought + pt2, JSON=JSON, chain_of_thought=True) for thought in thought_modifiers]

            prompts = [base_json] + personas_json + thought_json  
            incl_max_token = [1] + [1] * len(personas_json) + [0] * len(thought_json) 

        else:
            prompts = [company_content]
            incl_max_token = [1]
        
        for prompt, token_indicator in zip(prompts, incl_max_token):

            current_template = {
                "custom_id": str(id_num),
                "method": "POST", 
                "url": "/v1/chat/completions", 
                "body": {
                    "model": model, 
                    "messages": [{
                        "role": "user",
                        "content": prompt
                    }],
                    "temperature": 0
                }
            }
            if token_indicator:
                current_template["body"]["max_tokens"] = 35
            
            id_num += 1
            all_prompts.append(json.dumps(current_template))
            
    file.write('\n'.join(all_prompts) + '\n')
    return id_num

def generate_prompts(question, model, month, year):
    """
    Main function to generate prompts and write them to a file.
    """
    # Set input file paths
    current_directory = os.getcwd()
    print(f"Current working directory: {current_directory}")
    csv_file = f"./data/step0_realized/{month}{year}_realized.csv"
    base_prompt_file = f'./data/prompt_templates/q{question}base'

    # Set output file path
    if model == "gpt-4o-08-26":
        model = "gpt-4o"
    model_month_directory = f"./data/step1_batch_prompts/{model}/q{question}" 
    os.makedirs(model_month_directory, exist_ok=True)
    output_file_path = f"{model_month_directory}/q{question}_{month}{year}_prompts.jsonl"

    # Read in data and base prompt
    content = read_base_prompt(base_prompt_file, "")
    content_json = read_base_prompt(base_prompt_file, "_json")
    companies = pd.read_csv(csv_file)

    with open(output_file_path, 'w') as file:
        # Pass the file object to the function that writes to it
        new_id = write_prompt(companies=companies, content=content, JSON=False, file=file, id_num=0, model=model)
        new_id = write_prompt(companies=companies, content=content_json, JSON=True, file=file, id_num=new_id, model=model)

if __name__ == "__main__":
    # Set constants here
    for month in month_batches:
        for question in economic_questions:
            for year in years:
                for model in models:
                    generate_prompts(question, model, month, year)