import os
import glob
import pandas as pd
import json

REPO_DIR = "./prediction_headlines"

def merge_batched_responses(responses_batched_paths):
    responses = []
    for responses_batched_path in sorted(responses_batched_paths):
        responses_batched_file = pd.read_json(responses_batched_path, lines=True)
        print(f"Loaded {os.path.basename(responses_batched_path)}, n = {len(responses_batched_file)}")
        responses_batched_file["id"] = responses_batched_file["custom_id"].apply(lambda x: int(x))
        responses.append(responses_batched_file)
    responses = pd.concat(responses)
    return(responses)

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
        
        if (response["id"]==829) | (response["id"]==20828) | (response["id"]==24548) | (response["id"]==26143) | (response["id"]==33259): 
            response_text = response_text +'"}'

        if (response["id"]==33260): # | (response["id"]==34772): 
            print(f'id={response["id"]}, incorrect formatting, dropped')
            continue

        # print(response["id"])
        # print(response_text)
        response_json = json.loads(response_text)
        
        responses_decoded.append({
            "id": response["id"],
            "headline_llm": response_json["headline_llm"],
            "input_tokens": int(response.response["body"]["usage"]["prompt_tokens"]),
            "output_tokens": int(response.response["body"]["usage"]["completion_tokens"])
        })
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
        
    # else:
    #     print(df["id"])
    #     print(part_to_trim[:100])
    #     print(headline[:100])
    #     print(headline_llm[:100])
    df["headline_trim"] = part_to_trim
    df["headline"] = headline
    df["headline_llm"] = headline_llm

    return(df)

def main():
    data_dir = os.path.join(REPO_DIR, "Data")
    temp_dir = os.path.join(REPO_DIR, "Temp/LLM")
    os.makedirs(temp_dir, exist_ok=True)

    headlines = pd.read_csv(os.path.join(data_dir, f"headlines.csv"))
    prompts = pd.read_json(os.path.join(temp_dir, f"prompts.jsonl"), lines=True) 
    prompts.drop(columns=["messages"], inplace=True)

    # # Load and merge batched responses
    responses_batched_paths = glob.glob(os.path.join(temp_dir, f'responses_batched/*.jsonl'))
    responses = merge_batched_responses(responses_batched_paths)
    print(f"Appended all responses, n = {len(responses)}")
    responses = responses.merge(prompts[["id",  "prompt_template_id", "headline_id", "add_date"]], on="id")
    responses.set_index("id", inplace=True, drop=False)
    responses.sort_index(inplace=True)
    
    # decoded responses
    responses = decode_responses(responses)

    # merge prompts and headlines metadata with llm responses
    headlines_completion = prompts.merge(responses, on="id", validate="1:1").merge(headlines, on="headline_id", validate="m:1")

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
    headlines_completion_path = os.path.join(data_dir, f"headlines_completion.csv")
    headlines_completion.to_csv(headlines_completion_path, index=False)
    print(f"Saved {os.path.basename(headlines_completion_path)}, n = {len(headlines_completion)}, at {os.path.dirname(headlines_completion_path)}")

if __name__ == "__main__":
    main()
