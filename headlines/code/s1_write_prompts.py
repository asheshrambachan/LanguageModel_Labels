import os
import pandas as pd
from tqdm import tqdm
import json
from constants import personas, thought_modifiers, explanation, explanation_json, step0_path, step1_path, prompts_path 
from constants import month_batches, economic_questions, years, models
from helpers import confirm_overwrite

def format_content(content, JSON=False, chain_of_thought=False):
    """Formats the prompt based on strategy."""
    if chain_of_thought:
        content = content[:-1] + (explanation_json if JSON else explanation)
    return content

def read_base_prompt(base_prompt_file, suffix):
    """Reads the base prompt from a file."""
    file_path = os.path.join(base_prompt_file + suffix + '.txt')
    with open(file_path, 'r') as file:
        content = file.read()
    return content

def write_prompt(companies, content, JSON, file, id_num, model):
    """Generates prompts for each company in the dataframe."""
    model = "gpt-4o-08-26" if model == "gpt-4o" else model
    all_prompts = []

    for _, row in tqdm(companies.iterrows(), total=companies.shape[0]):
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
    """Main function to generate prompts and write them to a file."""  
    print(f"Writing prompts for {question}, {model},{month}, and {year}") 
    if not confirm_overwrite():
        return

    csv_file = os.path.join(step0_path, "realized", f"{month}{year}_realized.csv")
    base_prompt_file = os.path.join(prompts_path, f'q{question}base')

    # Check if the model needs modification
    model = "gpt-4o" if model == "gpt-4o-08-26" else model

    # Set output directory
    model_month_directory = os.path.join(step1_path, model, f'q{question}')
    os.makedirs(model_month_directory, exist_ok=True)

    # Read in data and base prompts
    content = read_base_prompt(base_prompt_file, "")
    content_json = read_base_prompt(base_prompt_file, "_json")
    companies = pd.read_csv(csv_file)

    if month == "oct":
        # Split the data in half
        mid_index = len(companies) // 2
        first_half = companies.iloc[:mid_index]
        second_half = companies.iloc[mid_index:]

        # Set output file paths for both halves
        output_file_path_1 = os.path.join(model_month_directory, f'q{question}_{month}first{year}_prompts.jsonl')
        output_file_path_2 = os.path.join(model_month_directory, f'q{question}_{month}second{year}_prompts.jsonl')

        # Write first half to first JSONL
        with open(output_file_path_1, 'w') as file1:
            new_id = write_prompt(companies=first_half, content=content, JSON=False, file=file1, id_num=0, model=model)
            new_id = write_prompt(companies=first_half, content=content_json, JSON=True, file=file1, id_num=new_id, model=model)

        # Write second half to second JSONL
        with open(output_file_path_2, 'w') as file2:
            new_id = write_prompt(companies=second_half, content=content, JSON=False, file=file2, id_num=0, model=model)
            new_id = write_prompt(companies=second_half, content_json=content_json, JSON=True, file=file2, id_num=new_id, model=model)
    else:
        # If not October, proceed as normal
        output_file_path = os.path.join(model_month_directory, f'q{question}_{month}{year}_prompts.jsonl')
        with open(output_file_path, 'w') as file:
            new_id = write_prompt(companies=companies, content=content, JSON=False, file=file, id_num=0, model=model)
            new_id = write_prompt(companies=companies, content=content_json, JSON=True, file=file, id_num=new_id, model=model)


if __name__ == "__main__":

    MONTHS = month_batches
    YEARS = years
    QUESTIONS = economic_questions
    MODELS = models

    # Set constants here
    for month in MONTHS:
        for question in QUESTIONS:
            for year in YEARS:
                for model in MODELS:
                    generate_prompts(question, model, month, year)