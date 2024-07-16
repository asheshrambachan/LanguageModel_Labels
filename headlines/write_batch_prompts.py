import pandas as pd
from openai import OpenAI
from tqdm import tqdm
import json
from constants import API_KEY, MODEL, TEMPERATURE, NUM_RESPONSES, personas, thought_modifiers, explanation, explanation_json, batch_template

# Configuration constants
CSV_FILE = "sample.csv"
BASE_PROMPT_FILE = 'base_prompt'
OUTPUT_FILE = "test_labels"

# Initialize OpenAI client
client = OpenAI(api_key=API_KEY)

def format_content(content, JSON=False, chain_of_thought=False):
    """
    Fetches the response from the OpenAI model.
    
    Parameters:
    - content (str): The prompt to send to the model.
    - JSON (bool): Whether to include JSON explanation.
    - chain_of_thought (bool): Whether to include chain of thought in the prompt.

    Returns:
    - response_text (str): The response from the model.
    """
    if chain_of_thought:
        content = content[:-1] + (explanation_json if JSON else explanation)
    
    return content

def read_base_prompt(suffix):
    """
    Reads the base prompt from a file.
    
    Parameters:
    - suffix (str): The suffix to determine the file name.

    Returns:
    - content (str): The content of the base prompt file.
    """
    with open(BASE_PROMPT_FILE + suffix + '.txt', 'r') as file:
        content = file.read()
    return content

def write_prompt(companies, content, JSON, file, id_num):
    """
    Generates responses for each company in the dataframe.
    
    Parameters:
    - companies (DataFrame): DataFrame containing company information.
    - content (str): The base content for the prompt.
    - json (bool): Whether to include JSON in the responses.
    - file: the file path where batch prompts will be written

    Returns:
    - prompts (list): List of prompts used.
    - responses (list): List of responses generated.
    """

    for index, row in tqdm(companies.iterrows(), total=companies.shape[0]):
        company = row["company_name"]
        headline = row["headline"]

        company_content = content % (company, headline, company)

        if JSON:
            base_json = company_content
            personas_json = [format_content(persona + company_content, JSON=JSON) for persona in personas]

            pt1, pt2 = company_content.split("Write", 1)[0], "Write" + company_content.split("Write", 1)[1]
            thought_json = [format_content(pt1 + thought + pt2, JSON=JSON) for thought in thought_modifiers]

            prompts = [base_json] + personas_json + thought_json           

        else:
            base = company_content
            prompts = [base]
        
        for prompt in prompts:
            current_template = batch_template
            prompt = '"' + prompt + '"'
            current_template["custom_id"] = str(id_num)
            id_num += 1
            current_template["body"]["messages"][0]["content"] = prompt
            file.write(json.dumps(current_template) + '\n')

    return id_num


def main():

    file_path = "batch_prompts.jsonl"
    content = read_base_prompt("")
    content_json = read_base_prompt("_json")
    companies = pd.read_csv(CSV_FILE)

    with open(file_path, 'w') as file:
        # Pass the file object to the function that writes to it
        new_id = write_prompt(companies=companies, content=content, JSON=False, file=file, id_num=0)
        new_id = write_prompt(companies=companies, content=content_json, JSON=True, file=file, id_num=new_id)

if __name__ == "__main__":
    main()
