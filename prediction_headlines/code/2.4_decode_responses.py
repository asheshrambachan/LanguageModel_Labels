import os
import pandas as pd
import json

REPO_DIR = "."
DATA_DIR = os.path.join(REPO_DIR, "prediction_headlines/data")

def decode_responses(responses):
    responses_decoded = []
    count = 0
    for _, response in responses.iterrows(): 
        finish_reason = response.response["body"]["choices"][0]["finish_reason"]
        response_text = response.response["body"]["choices"][0]["message"]["content"]
        
        if finish_reason!="stop":
            if (finish_reason=="length"):
                count = count + 1
                response_text = response_text +'"}'
                print(f'id={response["id"]}, finish_reason={finish_reason}, kept')
            else:
                print(f'id={response["id"]}, finish_reason={finish_reason}, dropped')
                continue
        
        if response["batch_req"] in [
            "batch_req_67192e397a94819081a47d9387b05f98", 
            "batch_req_6719314d32e08190963edd4ff7a2a9d5", 
            "batch_req_671931d084208190be644d99484fa033", 
            "batch_req_6719320c50e4819096917a2ed7a7b9c8", 
            "batch_req_671933083aac81909b1da00a93b9e7c9"
        ]: 
            response_text = response_text +'"}'

        if response["batch_req"] in [
            "batch_req_67193308546c819082de5264b1f4ff25",
            "batch_req_6924b1211d308190a3c93dc564093d92",
            "batch_req_6924b71e95c881908818d36495a5def2",
            "batch_req_6924b4cb52a8819092ef07f01ba113aa",
            "batch_req_6924b890d42c81908b80381f649aa7f2"
        ]: 
            print(f'id={response["id"]}, incorrect response, dropped')
            continue
        
        # if response["batch_req"] == "batch_req_6924b4cb52a8819092ef07f01ba113aa":
        #     response_json["headline_llm"] = "Morgan Stanley sticks with an underweight rating on Bank of New York Mellon Corp, citing valuation concerns and potential earnings headwinds."

        # if response["batch_req"] == "batch_req_6924b890d42c81908b80381f649aa7f2":
        #     response_json["headline_llm"] = "SunTrust moves to a Buy rating on Splunk with a $160 target, citing multiple growth drivers such as expanded security analytics, cloud adoption, and an expanding addressable market."
        
        try:
            response_json = json.loads(response_text)
            responses_decoded.append({
                "id": response["id"],
                "headline_llm": response_json["headline_llm"],
                "input_tokens": int(response.response["body"]["usage"]["prompt_tokens"]),
                "output_tokens": int(response.response["body"]["usage"]["completion_tokens"])
            })
        except:
            print(response["batch_req"])
            print(response["id"])
            print(response_text)
            continue

        
    print(f'Number of responses exceeding max_token = {count}')
    return(pd.json_normalize(responses_decoded))


import string
import re
import nltk
nltk.download('stopwords', quiet=True)
STOPWORDS = nltk.corpus.stopwords.words('english')

def clean_text(x, remove_stop_words=False):    
    # remove punctuation, lowercase, and remove tailing spaces
    x = re.sub('[{}]'.format(string.punctuation), '', x)
    x = re.sub(r'[^a-zA-Z0-9]', ' ', x.lower()).strip()
    words = x.split()

    # remove stopwords 
    if (remove_stop_words):
        words = [word for word in words if word not in set(STOPWORDS)]
        
    # join back into string and return (sklearn vectorizer wants string as input)
    return ' '.join(words)

def add_trimmed(df):
    part_to_trim = df["headline_trim"].strip()
    headline = df["headline"].strip()
    headline_llm = df["headline_llm"].strip()
    
    if (not headline_llm.startswith((part_to_trim))):
        # LLM model outputs sometimes include a leading space, and other times they don't, making it difficult to append to the headline text consistently. To handle this, we strip any leading spaces and manually add a space if the true summary starts with one.
        headline = headline.replace(part_to_trim, "", 1)
        if (headline[0]==" "):
            headline_llm = " " + headline_llm
        
        headline = part_to_trim + headline
        headline_llm = part_to_trim + headline_llm
        
    df["headline_trim"] = part_to_trim
    df["headline"] = headline
    df["headline_llm"] = headline_llm

    return(df)

def read_and_merge_jsonl_files(files):
	# Extract directory and prefix
	all_data = []

	# Traverse through the directory
	for file in sorted(files):
		if file.endswith('.jsonl'):
			print(f"Reading: {file}")
			df = pd.read_json(file, lines=True)
			all_data.append(df)

	# Combine all DataFrames into one
	combined_df = pd.concat(all_data, ignore_index=True)
	print(f"Combined DataFrame has {len(combined_df)} rows.")

	return combined_df

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
            # trim headline description and formate date
            headline_trim = trim(headline["headline"], template["trim_prop"])

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
                "headline_trim": headline_trim
            }
            prompts.append(prompt)

    return(pd.json_normalize(prompts))


def main():
    headlines = pd.read_csv(os.path.join(DATA_DIR, f"headlines.csv"))
    prompting_strategies = pd.read_csv(os.path.join(DATA_DIR, "prompt_templates.csv"))
    prompts_p1 = create_prompts(prompting_strategies, headlines)

    prompting_strategies = pd.read_csv(os.path.join(DATA_DIR, "prompt_templates_p2.csv"))
    prompts_p2 = create_prompts(prompting_strategies, headlines)

    # Load and merge batched responses
    responses_dir = os.path.join(DATA_DIR, "llm/responses_batched")
	
    responses_path_p1 = [os.path.join(responses_dir, name) for name in os.listdir(responses_dir) if ("gpt-5" not in name)]
    responses_p1 = read_and_merge_jsonl_files(responses_path_p1)
    responses_p1["batch_req"] = responses_p1["id"]
    responses_p1["id"] = responses_p1["custom_id"].apply(lambda x: int(x))
    responses_p1 = responses_p1.merge(prompts_p1[["id",  "prompt_template_id", "headline_id", "add_date"]], on="id")
    responses_p1.set_index("id", inplace=True, drop=False)
    responses_p1.sort_index(inplace=True)
    responses_p1 = decode_responses(responses_p1)
    responses_p1 = prompts_p1.merge(responses_p1, on="id", validate="1:1")

    responses_path_p2 = [os.path.join(responses_dir, name) for name in os.listdir(responses_dir) if ("gpt-5" in name)]
    responses_p2 = read_and_merge_jsonl_files(responses_path_p2)
    responses_p2["batch_req"] = responses_p2["id"]
    responses_p2["id"] = responses_p2["custom_id"].apply(lambda x: int(x))
    responses_p2 = responses_p2.merge(prompts_p2[["id",  "prompt_template_id", "headline_id", "add_date"]], on="id")
    responses_p2.set_index("id", inplace=True, drop=False)
    responses_p2.sort_index(inplace=True)
    responses_p2 = decode_responses(responses_p2)
    responses_p2 = prompts_p2.merge(responses_p2, on="id", validate="1:1")

    # merge prompts and headlines metadata with llm responses
    headlines_completion = (
        pd.concat([responses_p1, responses_p2])
        .merge(headlines, on="headline_id", validate="m:1")
    )

    # Add the provided beginning of headline to headline_llm if not included
    headlines_completion = headlines_completion.apply(lambda x: add_trimmed(x), axis=1)

    # Remove non-alphanumeric characters, keeping stop-words
    headlines_completion["headline_clean"] = headlines_completion["headline"].apply(lambda x: clean_text(x, remove_stop_words=False))
    headlines_completion["headline_llm_clean"] = headlines_completion["headline_llm"].apply(lambda x: clean_text(x, remove_stop_words=False))

    headlines_completion.set_index("id", inplace=True, drop=True)
    headlines_completion.sort_index(inplace=True, ignore_index=True)
    headlines_completion["id"] = headlines_completion.index
    
    # print mean input and output tokens
    print(headlines_completion[["prompt_template_id", "input_tokens", "output_tokens"]].groupby("prompt_template_id").agg(['mean']))

    # save
    headlines_completion_path = os.path.join(DATA_DIR, f"headlines_completion.csv")
    headlines_completion.to_csv(headlines_completion_path, index=False)
    print(f"Saved {os.path.basename(headlines_completion_path)}, n = {len(headlines_completion)}, at {os.path.dirname(headlines_completion_path)}")

if __name__ == "__main__":
    main()
