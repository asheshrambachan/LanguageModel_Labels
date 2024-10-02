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
    for _, response in responses.iterrows(): 
        finish_reason = response.response["body"]["choices"][0]["finish_reason"]
        response_text = response.response["body"]["choices"][0]["message"]["content"]
        
        if finish_reason!="stop":
            if (finish_reason=="length"):
                response_text = response_text +'"}'
                print(f'ID={response["ID"]}, finish_reason={finish_reason}, kept')
            else:
                print(f'ID={response["ID"]}, finish_reason={finish_reason}, dropped')
                continue
        
        if response["ID"]==7323:
            response_text = response_text +'"}'
        
        # print(response_text)
        response_json = json.loads(response_text)
        
        responses_decoded.append({
            "ID": response["ID"],
            "DescriptionLLM": response_json["DescriptionLLM"],
            "InputTokens": int(response.response["body"]["usage"]["prompt_tokens"]),
            "OutputTokens": int(response.response["body"]["usage"]["completion_tokens"])
        })
    return(pd.json_normalize(responses_decoded))

# def count_words(description):
#     words = description.split() # Split the description into words
#     word_count = len(words) # Total number of words
#     return word_count

import string
import re
import nltk

REPO_DIR = "."
nltk.download('stopwords', quiet=True)
nltk.download('wordnet', quiet=True)
STOPWORDS = nltk.corpus.stopwords.words('english')
LEMMATIZER = nltk.stem.WordNetLemmatizer()

def clean_text(x):    
    # remove punctuation, lowercase, and remove tailing spaces
    x = re.sub('[{}]'.format(string.punctuation), '', x)
    x = re.sub(r'[^a-zA-Z]', ' ', x.lower()).strip()

    # remove stopwords 
    words = [word for word in x.split() if word not in set(STOPWORDS)]

    # stemming (maybe omit and see if results change?)
    words = [LEMMATIZER.lemmatize(word) for word in words]
    
    # join back into string and return (sklearn vectorizer wants string as input)
    return ' '.join(words)

def trim(df):
    # Since some responses still contain the first part of the text that we asked in the prompt to not include, we have to trim them mannually
    df["DescriptionClean"] = df["Description"]
    df["DescriptionLLMClean"] = df["DescriptionLLM"]
    
    temp = df["DescriptionLLMClean"].strip().replace(df["DescriptionTrim"].strip(), "", 1)
    if ((temp=="") | temp.startswith(("The bill", "This bill","A bill"))):
        # if true do not do any changes for the Description nor DescriptionLLM
        print(f'ID={df["ID"]}, did not trim Description nor DescriptionLLM because they start differently or result after trimming is null')
        # ((df["ID"]==68259) | (df["ID"]==68260) | (df["ID"]==43356) | (df["ID"]==30460) | (df["ID"]==28956)| (df["ID"]==28955)):
        # print(f'{df["ID"]},\n{df["DescriptionTrim"]}\n{temp}\n\n')
    else:
        df["DescriptionLLMClean"] = temp
        if ((df["ID"]==74659)|(df["ID"]==74660)):
            df["DescriptionLLMClean"]=df["DescriptionLLMClean"].replace(df["DescriptionTrim"].upper().strip(), "", 1)

        if (df["ID"]==73092):
            df["DescriptionLLMClean"]=df["DescriptionLLMClean"].replace("Relating to criminal penalties for violations of the Co", "", 1)

        if (df["ID"]==70428):
            df["DescriptionLLMClean"]=df["DescriptionLLMClean"].replace("To improve Federal laws relating to the trans", "", 1)

        #   if ((df["DescriptionLLMClean"][0].isupper()) & (df["ID"]<28955)):
        #       print(f'{df["ID"]},\n{df["DescriptionTrim"]}\n{df["DescriptionLLMClean"]}\n\n')

        df["DescriptionClean"] = df["DescriptionClean"].strip().replace(df["DescriptionTrim"].strip(), "", 1)
    
    df["DescriptionClean"] = clean_text(df["DescriptionClean"])
    df["DescriptionLLMClean"] = clean_text(df["DescriptionLLMClean"])

    return(df)

def main():
    data_dir = os.path.join(REPO_DIR, "Data/Prediction")
    temp_dir = os.path.join(REPO_DIR, "Temp/Prediction")
    os.makedirs(temp_dir, exist_ok=True)

    bills = pd.read_csv(os.path.join(data_dir, f"bills_run2.csv"))
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
    bills_llm_passage.set_index("ID", inplace=True, drop=False)
    bills_llm_passage.sort_index(inplace=True)

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
    bills_llm_completion.set_index("ID", inplace=True, drop=False)
    bills_llm_completion.sort_index(inplace=True)

    # Trim Description and DescriptionLLM if the begin the same
    bills_llm_completion = bills_llm_completion.apply(lambda x: trim(x), axis=1)

    # print mean input and output tokens
    print(bills_llm_completion[["AddIntrDate", "InputTokens", "OutputTokens"]].groupby("AddIntrDate").agg(['mean']))

    # save
    bills_llm_completion_path = os.path.join(data_dir, f"bills_llm_completion.csv")
    bills_llm_completion.to_csv(bills_llm_completion_path, index=False)
    print(f"Saved {os.path.basename(bills_llm_completion_path)}, n = {len(bills_llm_completion)}, at {os.path.dirname(bills_llm_completion_path)}")

if __name__ == "__main__":
    main()
