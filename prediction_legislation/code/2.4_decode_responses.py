import os
import pandas as pd
import json

REPO_DIR = "."
DATA_DIR = os.path.join(REPO_DIR, "prediction_legislation/data")

# a function to trim a string 
def trim(text, trimprop):
    keepprop = min(1-trimprop, 1)
    return text[:int(len(text) * keepprop)]

def create_prompts(prompting_strategies, bills):
    id = 0
    prompts = []
    for _, bill in bills.iterrows():
        for _, strategy in prompting_strategies.iterrows():
            bill_description = bill["Description"]

            # trim bill description
            if (strategy["TrimText"]):
                bill_description = trim(bill_description, strategy["TrimProp"])

            id = id + 1
            prompt = {
                "ID": id,
                "BillID": bill["BillID"],
                "PromptingStrategyID": strategy["PromptingStrategyID"],
                "PromptingStrategyName": strategy["PromptingStrategyName"],
                "ResponseFormat": strategy["ResponseFormat"],
                "TrimText": strategy["TrimText"],
                "AddIntrDate": strategy["AddIntrDate"],
                "Model": strategy["Model"],
                "Temperature": strategy["Temperature"],
                "MaxTokens": strategy["MaxTokens"],
                "DescriptionTrim": bill_description
            }
            prompts.append(prompt)

    return(pd.json_normalize(prompts))

def decode_responses_passage(responses):
	responses_decoded = []
	for _, response in responses.iterrows(): 
		response_text = response.response["body"]["choices"][0]["message"]["content"]
		response_json = json.loads(response_text)

		try:
			if (response_json["PassSLLM"] is None) | (response_json["PassHLLM"] is None):
				# print(f'ID={response["ID"]}, PassSLLM={response_json["PassSLLM"]}, PassHLLM={response_json["PassHLLM"]}, dropped')
				continue
			response_json["PassSLLM"] = int(response_json["PassSLLM"])
			response_json["PassHLLM"] = int(response_json["PassHLLM"])

			if response_json["PassSLLM"] == -1:
				continue

			if response_json["PassHLLM"] == -1:
				continue

		except:
			# print(f"{response["ID"]} dropped: {response_text}")
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
				# print(response_text)
			else:
				print(f'ID={response["ID"]}, finish_reason={finish_reason}, dropped')
				# print(response_text)
				continue
		
		if (response["id"]=='batch_req_67103334ede081909e1242340d8250f7'): 
			response_text = response_text +'"}'

		try:
			response_json = json.loads(response_text)
			responses_decoded.append({
				"ID": response["ID"],
				"DescriptionLLM": response_json["DescriptionLLM"],
				"InputTokens": int(response.response["body"]["usage"]["prompt_tokens"]),
				"OutputTokens": int(response.response["body"]["usage"]["completion_tokens"])
			})
		except:
			print(response["ID"])
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

    df["DescriptionTrim"] = part_to_trim
    df["Description"] = description
    df["DescriptionLLM"] = description_llm

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

def main():
    bills = pd.read_csv(os.path.join(DATA_DIR, f"bills.csv"))
    
    prompting_strategies = pd.read_csv(os.path.join(DATA_DIR, "prompt_templates.csv"))
    prompts_p1 = create_prompts(prompting_strategies, bills)

    prompting_strategies = pd.read_csv(os.path.join(DATA_DIR, "prompt_templates_p2.csv"))
    prompts_p2 = create_prompts(prompting_strategies, bills)
    
    # Load and merge batched responses
    responses_dir = os.path.join(DATA_DIR, "llm/responses_batched")
    
    responses_path_p1 = [os.path.join(responses_dir, name) for name in os.listdir(responses_dir) if ("gpt-5" not in name)]
    responses_p1 = read_and_merge_jsonl_files(responses_path_p1)
    responses_p1["ID"] = responses_p1["custom_id"].apply(lambda x: int(x))
    responses_p1 = responses_p1.merge(prompts_p1[["ID",  "PromptingStrategyID", "PromptingStrategyName", "BillID", "TrimText", "AddIntrDate"]], on="ID")
    responses_p1.set_index("ID", inplace=True, drop=False)
    responses_p1.sort_index(inplace=True)

    responses_path_p2 = [os.path.join(responses_dir, name) for name in os.listdir(responses_dir) if ("gpt-5" in name)]
    responses_p2 = read_and_merge_jsonl_files(responses_path_p2)
    responses_p2["ID"] = responses_p2["custom_id"].apply(lambda x: int(x))
    responses_p2 = responses_p2.merge(prompts_p2[["ID",  "PromptingStrategyID", "PromptingStrategyName", "BillID", "TrimText", "AddIntrDate"]], on="ID")
    responses_p2.set_index("ID", inplace=True, drop=False)
    responses_p2.sort_index(inplace=True)

    # Pass 
    # Decoded Pass responses
    responses_p1_passage = responses_p1.query('PromptingStrategyName=="Predict Bill Passage"')
    responses_p1_passage = decode_responses_passage(responses_p1_passage)

    responses_p2_passage = responses_p2.query('PromptingStrategyName=="Predict Bill Passage"')
    responses_p2_passage = decode_responses_passage(responses_p2_passage)

    # merge prompts and bills metadata with llm responses
    bills_passage_p1 = (
        prompts_p1
        .query('PromptingStrategyName=="Predict Bill Passage"')
        .merge(responses_p1_passage, on="ID", validate="1:1", how="left")
        .merge(bills, on="BillID", validate="m:1")
    )
    bills_passage_p2 = (
        prompts_p2
        .query('PromptingStrategyName=="Predict Bill Passage"')
        .merge(responses_p2_passage, on="ID", validate="1:1", how="left")
        .merge(bills, on="BillID", validate="m:1")
    )

    bills_passage = pd.concat([bills_passage_p1, bills_passage_p2], ignore_index=True)
    bills_passage.set_index("ID", inplace=True, drop=True)
    bills_passage.sort_index(inplace=True, ignore_index=True)
    print(bills_passage.shape)

    # print mean input and output tokens
    print(bills_passage[["AddIntrDate", "InputTokens", "OutputTokens"]].groupby("AddIntrDate").agg(['mean']))

    # save
    bills_passage_path = os.path.join(DATA_DIR, f"bills_passage.csv")
    bills_passage.to_csv(bills_passage_path, index=False)
    print(f"Saved {os.path.basename(bills_passage_path)}, n = {len(bills_passage)}, at {os.path.dirname(bills_passage_path)}")


    # Completion
    responses_p1_completion = responses_p1.query('PromptingStrategyName == "Complete Bill Summary"')
    responses_p1_completion = decode_responses_completion(responses_p1_completion)
    print(responses_p1_completion.shape)

    responses_p2_completion = responses_p2.query('PromptingStrategyName == "Complete Bill Summary"')
    responses_p2_completion = decode_responses_completion(responses_p2_completion)
    print(responses_p2_completion.shape)

    # merge prompts and bills metadata with llm responses
    responses_p1_completion = prompts_p1.merge(responses_p1_completion, on="ID", validate="1:1")
    responses_p2_completion = prompts_p2.merge(responses_p2_completion, on="ID", validate="1:1")

    bills_completion = (
		pd.concat([responses_p1_completion, responses_p2_completion], ignore_index=True)
		.merge(bills, on="BillID", validate="m:1")
    )

    # Add the provided beginning of bill summary to DescriptionLLM if not included
    bills_completion = bills_completion.apply(lambda x: add_trimmed(x), axis=1)

    # Remove non-alphanumeric characters, keeping stop-words
    bills_completion["DescriptionClean"] = bills_completion["Description"].apply(lambda x: clean_text(x, remove_stop_words=False))
    bills_completion["DescriptionLLMClean"] = bills_completion["DescriptionLLM"].apply(lambda x: clean_text(x, remove_stop_words=False))

    bills_completion.set_index("ID", inplace=True, drop=True)
    bills_completion.sort_index(inplace=True, ignore_index=True)
    bills_completion["ID"] = bills_completion.index

    # print mean input and output tokens
    print(bills_completion[["AddIntrDate", "InputTokens", "OutputTokens"]].groupby("AddIntrDate").agg(['mean']))

    # save
    bills_completion_path = os.path.join(DATA_DIR, f"bills_completion.csv")
    bills_completion.to_csv(bills_completion_path, index=False)
    print(f"Saved {os.path.basename(bills_completion_path)}, n = {len(bills_completion)}, at {os.path.dirname(bills_completion_path)}")


if __name__ == "__main__":
    main()
