import os
import glob
import pandas as pd
import json

REPO_DIR = "."

def merge_batched_responses(responses_batched_paths):
    responses = []
    for responses_batched_path in sorted(responses_batched_paths):
        responses_batched_file = pd.read_json(responses_batched_path, lines=True)
        print(f"Loaded {os.path.basename(responses_batched_path)}, n = {len(responses_batched_file)}")
        responses_batched_file["ID"] = responses_batched_file["custom_id"].apply(lambda x: int(x))
        responses.append(responses_batched_file)
    responses = pd.concat(responses)
    return(responses)

def decode_responses_passage(responses):
    responses_decoded = []
    for _, response in responses.iterrows(): 
        response_text = response.response["body"]["choices"][0]["message"]["content"]
        response_json = json.loads(response_text)

        if (response_json["PassSLLM"] is None) | (response_json["PassHLLM"] is None):
            print(f'ID={response["ID"]}, PassSLLM={response_json["PassSLLM"]}, PassHLLM={response_json["PassHLLM"]}, dropped')
            continue

        responses_decoded.append({
            "ID": response["ID"],
            "PassSLLM": response_json["PassSLLM"],
            "PassHLLM": response_json["PassHLLM"],
            "InputTokens": int(response.response["body"]["usage"]["prompt_tokens"]),
            "OutputTokens": int(response.response["body"]["usage"]["completion_tokens"])
        })
    return(pd.json_normalize(responses_decoded))

def decode_responses_completion(responses):
    responses_decoded = []
    count = 0
    for _, response in responses.iterrows(): 
        finish_reason = response.response["body"]["choices"][0]["finish_reason"]
        response_text = response.response["body"]["choices"][0]["message"]["content"]
        
        if finish_reason!="stop":
            if (finish_reason=="length"):
                count = count + 1
                response_text = response_text +'"}'
                print(f'ID={response["ID"]}, finish_reason={finish_reason}, kept')
            else:
                print(f'ID={response["ID"]}, finish_reason={finish_reason}, dropped')
                continue
        
        if (response["ID"]==35875): 
            response_text = response_text +'"}'

        response_json = json.loads(response_text)
        
        responses_decoded.append({
            "ID": response["ID"],
            "DescriptionLLM": response_json["DescriptionLLM"],
            "InputTokens": int(response.response["body"]["usage"]["prompt_tokens"]),
            "OutputTokens": int(response.response["body"]["usage"]["completion_tokens"])
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
    part_to_trim = df["DescriptionTrim"].strip()
    description = df["Description"].strip()
    description_llm = df["DescriptionLLM"].strip()

    part_to_trim = part_to_trim.replace("A bill entitled: ", "", 1)
    description = description.replace("A bill entitled: ", "", 1)
    description_llm = description_llm.replace("A bill entitled: ", "", 1)

    if (not description_llm.startswith((part_to_trim, "The bill", "This bill", "A bill", "The "))):
        # LLM model outputs sometimes include a leading space, and other times they don't, making it difficult to append to the bill summary consistently. To handle this, we strip any leading spaces and manually add a space if the true summary starts with one.
        description = description.replace(part_to_trim, "", 1)
        if (description[0]==" "):
            description_llm = " " + description_llm
        
        description = part_to_trim + description
        description_llm = part_to_trim + description_llm
    # else:
    #     print(df["ID"])
    #     print(part_to_trim[:100])
    #     print(description[:100])
    #     print(description_llm[:100])

    df["DescriptionTrim"] = part_to_trim
    df["Description"] = description
    df["DescriptionLLM"] = description_llm

    return(df)

def main():
    data_dir = os.path.join(REPO_DIR, "Data")
    temp_dir = os.path.join(REPO_DIR, "Temp/LLM")
    os.makedirs(temp_dir, exist_ok=True)

    bills = pd.read_csv(os.path.join(data_dir, f"bills.csv"))
    prompts = pd.read_json(os.path.join(temp_dir, f"prompts.jsonl"), lines=True) 
    prompts.drop(columns=["Messages"], inplace=True)

    # # Load and merge batched responses
    responses_batched_paths = glob.glob(os.path.join(temp_dir, f'responses_batched/*.jsonl'))
    responses = merge_batched_responses(responses_batched_paths)
    print(f"Appended all responses, n = {len(responses)}")
    responses = responses.merge(prompts[["ID",  "PromptingStrategyID", "PromptingStrategyName", "BillID", "TrimText", "AddIntrDate"]], on="ID")
    responses.set_index("ID", inplace=True, drop=False)
    responses.sort_index(inplace=True)

    # Pass 
    responses_passage = responses.loc[responses["PromptingStrategyName"]=="Predict Bill Passage"]

    # Decoded responses
    responses_passage = decode_responses_passage(responses_passage)
    
    # merge prompts and bills metadata with llm responses
    bills_llm_passage = prompts.merge(responses_passage, on="ID", validate="1:1").merge(bills, on="BillID", validate="m:1")
    bills_llm_passage.set_index("ID", inplace=True, drop=True)
    bills_llm_passage.sort_index(inplace=True, ignore_index=True)


    # print mean input and output tokens
    print(bills_llm_passage[["AddIntrDate", "InputTokens", "OutputTokens"]].groupby("AddIntrDate").agg(['mean']))

    # save
    bills_llm_passage_path = os.path.join(data_dir, f"bills_llm_passage.csv")
    bills_llm_passage.to_csv(bills_llm_passage_path, index=False)
    print(f"Saved {os.path.basename(bills_llm_passage_path)}, n = {len(bills_llm_passage)}, at {os.path.dirname(bills_llm_passage_path)}")

    # Completion
    responses_completion = responses.loc[responses["PromptingStrategyName"]=="Complete Bill Summary"]

    # decoded responses
    responses_completion = decode_responses_completion(responses_completion)

    # merge prompts and bills metadata with llm responses
    bills_llm_completion = prompts.merge(responses_completion, on="ID", validate="1:1").merge(bills, on="BillID", validate="m:1")

    # Add the provided beginning of bill summary to DescriptionLLM if not included
    bills_llm_completion = bills_llm_completion.apply(lambda x: add_trimmed(x), axis=1)

    # Remove non-alphanumeric characters, keeping stop-words
    bills_llm_completion["DescriptionClean"] = bills_llm_completion["Description"].apply(lambda x: clean_text(x, remove_stop_words=False))
    bills_llm_completion["DescriptionLLMClean"] = bills_llm_completion["DescriptionLLM"].apply(lambda x: clean_text(x, remove_stop_words=False))

    bills_llm_completion.set_index("ID", inplace=True, drop=True)
    bills_llm_completion.sort_index(inplace=True, ignore_index=True)
    bills_llm_completion["ID"] = bills_llm_completion.index
    
    # print mean input and output tokens
    print(bills_llm_completion[["AddIntrDate", "InputTokens", "OutputTokens"]].groupby("AddIntrDate").agg(['mean']))

    # save
    bills_llm_completion_path = os.path.join(data_dir, f"bills_llm_completion.csv")
    bills_llm_completion.to_csv(bills_llm_completion_path, index=False)
    print(f"Saved {os.path.basename(bills_llm_completion_path)}, n = {len(bills_llm_completion)}, at {os.path.dirname(bills_llm_completion_path)}")

if __name__ == "__main__":
    main()
