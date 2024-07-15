import pandas as pd
from openai import OpenAI
from tqdm import tqdm
from constants import API_KEY, MODEL, TEMPERATURE, NUM_RESPONSES, personas, thought_modifiers, explanation, explanation_json

# Configuration constants
JSON_SWITCH = [True, False]
CSV_FILE = "sample.csv"
BASE_PROMPT_FILE = 'base_prompt'
OUTPUT_FILE = "test_labels"

# Initialize OpenAI client
client = OpenAI(api_key=API_KEY)

def get_response(content, JSON=False, chain_of_thought=False):
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
    
    response = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": content}],
        logprobs=True,
        n=NUM_RESPONSES,
        temperature=TEMPERATURE
    )

    response_text = response.choices[0].message.content
    return response_text

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

def generate_responses(companies, content, switch):
    """
    Generates responses for each company in the dataframe.
    
    Parameters:
    - companies (DataFrame): DataFrame containing company information.
    - content (str): The base content for the prompt.
    - switch (bool): Whether to include JSON in the responses.

    Returns:
    - prompts (list): List of prompts used.
    - responses (list): List of responses generated.
    """
    prompts = []
    responses = []

    for index, row in tqdm(companies.iterrows(), total=companies.shape[0]):
        company = row["company_name"]
        headline = row["headline"]

        company_content = content % (company, headline, company)

        base_q = company_content
        try:
            base_a = get_response(content=company_content, JSON=switch)
        except Exception as e:
            base_a = None
            print(f"Error generating base response for {company}: {e}")

        personas_q = [persona + company_content for persona in personas]
        personas_a = []
        for persona_q in personas_q:
            try:
                personas_a.append(get_response(content=persona_q, JSON=switch))
            except Exception as e:
                personas_a.append(None)
                print(f"Error generating persona response: {e}")

        thought_q = []
        thought_a = []
        pt1, pt2 = company_content.split("Write", 1)[0], "Write" + company_content.split("Write", 1)[1]
        for thought in thought_modifiers:
            thought_prompt = pt1 + thought + pt2 + (explanation_json if switch else explanation)
            thought_q.append(thought_prompt)
            try:
                thought_a.append(get_response(content=thought_prompt, chain_of_thought=True, JSON=switch))
            except Exception as e:
                thought_a.append(None)
                print(f"Error generating thought-modifier response: {e}")

        prompts.extend([base_q] + personas_q + thought_q)
        responses.extend([base_a] + personas_a + thought_a)

    return prompts, responses

def main():
    for switch in JSON_SWITCH:
        suffix = "_json" if switch else ""
        content = read_base_prompt(suffix)
        companies = pd.read_csv(CSV_FILE)
        
        prompts, responses = generate_responses(companies, content, switch)

        data = pd.DataFrame({
            "prompt": prompts,
            "response": responses
        })

        data.to_csv(OUTPUT_FILE + suffix + ".csv", index=False)

if __name__ == "__main__":
    main()
