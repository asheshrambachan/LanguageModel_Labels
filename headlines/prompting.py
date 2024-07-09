from openai import OpenAI
import pandas as pd
import numpy as np
from tqdm import tqdm
from constants import API_KEY, MODEL, TEMPERATURE, NUM_RESPONSES, personas, thought_modifiers, explanation

# define a response function that gives us the LLM's response to a user prompt
def get_response(content, chain_of_thought = False):
    response = client.chat.completions.create(
        model = MODEL,
        messages=[
        {"role": "user", "content": content}
        ],
        logprobs = True,
        n = NUM_RESPONSES,
        temperature = TEMPERATURE

    )   

    response_text = response.choices[0].message.content
    return(response_text)

# define a response function that gives us the LLM's response to a user prompt
def get_response_json(content, chain_of_thought = False):
    system = 'Output a JSON object structured like {"headline type": "positive" or "negative" or "neutral", "confidence": 0-1 value of your confidence in the headline type, "magnitude": magnitude of positive or negative for the headline type}'
    if(chain_of_thought):
        system = system[:-1] + ', "explanation": once sentence explanation for your headline type answer}'
    response = client.chat.completions.create(
        model = MODEL,
        messages=[
        {"role": "system", "content": system},
        {"role": "user", "content": content}
        ],
        logprobs = True,
        n = NUM_RESPONSES,
        temperature = TEMPERATURE

    )

    response_text = response.choices[0].message.content
    return(response_text)

# read in the base prompt
with open('base_prompt_json.txt', 'r') as file:
    content = file.read()

# read in our sample company df
companies = pd.read_csv("sample.csv").head(100)

# create open AI client with api key
client = OpenAI(api_key = API_KEY)

prompts = []
responses = []
# iterate over all the companies in the sample
for index, row in companies.iterrows():
    company = row["company_name"]
    headline = row["headline"]

    company_content = content % (company, headline, company)

    base_q = company_content
    base_a = get_response_json(content=company_content)

    personas_q = []
    personas_a = []
    for persona in personas:
        personas_q.append(persona + company_content)
        try: 
            personas_a.append(get_response_json(content=(persona + company_content)))
        except:
            personas_a.append(None)

    thought_q = []
    thought_a = []
    pt1, pt2 = company_content.split("Write", 1)[0], "Write" + company_content.split("Write", 1)[1]
    for thought in thought_modifiers:
        thought_q.append(pt1 + thought + pt2 + explanation)
        try: 
            thought_a.append(get_response_json(content=(pt1 + thought + pt2 + explanation), chain_of_thought=True))
        except:
            thought_a.append(None)


    prompts = prompts + [base_q] + personas_q + thought_q
    responses = responses + [base_a] + personas_a + thought_a

    print(index)

data = pd.DataFrame({
    "prompt": prompts,
    "response": responses
})

data.to_csv("test_labels_json.csv")
        

