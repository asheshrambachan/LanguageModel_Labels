import os
import glob
import pandas as pd
import json
import re
import numpy as np

REPO_DIR = '.'
DATA_DIR = os.path.join(REPO_DIR, "estimation_legislation/data")

MAJOR_CODE = pd.read_csv(os.path.join(DATA_DIR, "major_topics.csv")).set_index('Major')['MajorText'].to_dict()

def decode_responses(responses):
	responses_decoded = []
	for _, response in responses.iterrows(): 
		response_text = response.response["body"]["choices"][0]["message"]["content"]

		if response["ResponseFormat"]=="JSON":
			temp = json.loads(response_text)
			major = int(temp["Category"])
			confidence = float(temp["Confidence"])
			explanation = temp["Explanation"] if response["AddExplanation"] else None
		else:
			pattern = r'^(\d+)\s*[,]{0,1}\s*[\r\n]{0,1}\s*([0-9]\.[0-9]{2})\s*[,]{0,1}[\r\n]{0,1}?\s*(.*)?$'
			match = re.match(pattern, response_text)
			major = int(match.group(1))
			confidence = float(match.group(2))
			explanation = match.group(3) if response["AddExplanation"] else None
		
		responses_decoded.append({
			"ID": response["ID"],
			"MajorLLM": major,
			"MajorTextLLM": MAJOR_CODE[major],
			"ConfidenceLLM": confidence,
			"ExplanationLLM": explanation,
			"InputTokens": int(response.response["body"]["usage"]["prompt_tokens"]),
			"OutputTokens": int(response.response["body"]["usage"]["completion_tokens"])
		})
	return(pd.json_normalize(responses_decoded))

def decode_responses_p2(responses):
	responses_decoded = []
	for _, response in responses.iterrows(): 
		response_text = response.response["body"]["choices"][0]["message"]["content"]

		if response["ResponseFormat"]=="JSON":
			temp = json.loads(response_text)

			if ('Category' not in temp):
				if ('result' in temp):
					temp = temp['result']
				elif ('Result' in temp):
					temp = temp['Result']
				elif ('Final Classification' in temp):
					temp = temp['Final Classification']
				elif ('Classification' in temp):
					temp = temp['Classification']
				elif ('Answer' in temp):
					temp = temp['Answer']
				elif (' Category' in temp):
					temp['Category'] = temp[' Category']
				elif ('JSON' in temp):
					temp = temp['JSON']
				elif ('Resulting JSON' in temp): 
					temp = temp['Resulting JSON']

			if response['id'] == 'batch_req_691e0885802081909174d9114e0a42dd':
				temp = {
					"Category": 14,
					"Confidence": 0.85,
					"Explanation": "The bill targets banking sector regulation and securities market oversight rather than broader macroeconomic, labor, health, or other policy areas."
				}
				
			if response['id'] == 'batch_req_691e0b9664e48190b89e56e9ff62d2cb':
				temp = {"Category": 9}

			if response['id'] == 'batch_req_691e0c20e14881909f847a8aa4f2d3bd':
				temp = {"Category": 20}

			if response['id'] == 'batch_req_691e0c5107448190915993f9491a1841':
				temp = {"Category": 15}
			
			if response['id'] == 'batch_req_691e0f9829b48190a04108026b3f47b7':
				temp = {"Category": 11}

			if response['id'] == 'batch_req_691e116a7a488190a3b2433fbcbcf900':
				temp = {"Category": 20}

			if response['id'] == 'batch_req_691e12c8a04481908e6ef08c8a044b48':
				temp = {
					"Category": 3,
					"Confidence": 0.82,
					"Explanation": "the bill focuses on a health condition and presumptive service-connected benefits for veterans."
				}

			if response['id'] == 'batch_req_691e1310b4308190beaa474044fb9f9d':
				temp = {
					"Category": 5,
					"Explanation": "The bill concerns adjusting pay for federal employees (post office staff), which falls under labor and employment rather than broader government operations or other topics."
				}

			if response['id'] == 'batch_req_691e14d8a8cc81909154189e8bd103ae':
				temp = {"Category": 3}

			if response['id'] == 'batch_req_691e14e821e08190a49cd8f10f9c264d':
				temp = {"Category": 11}

			if response['id'] == 'batch_req_691e1649e8908190a0a0036ca1005a7e':
				temp = {"Category": 2}

			if response['id'] == 'batch_req_691e165094cc8190899a14609feb913d':
				temp = {
					"Category": 8,
					"Confidence": 0.70,
					"Explanation": "DST legislation influences energy efficiency and scheduling, hence Energy."
				}
			if response['id'] == 'batch_req_691e16530e6c8190a5708631655c51f6':
				temp = {
					"Category": 15,
					"Confidence": 0.85,
					"Explanation": "This is a defense-related policy bill addressing military personnel and pay."
				}

			if response['id'] == 'batch_req_691e82bcd3788190a0dbd6891ea587b1':
				temp = {
					"Category": 20,
					"Confidence": 0.90,
					"Explanation": "The bill concerns the administration and legal status of a federal oil and gas lease, which falls under public lands and water management."
				}

			if response['id'] =='batch_req_691e16870ee481908d690debe5cccc0b':
				temp = {"Category": 19}

			if response['id'] == 'batch_req_691e176001108190bcbbcd739da41128':
				temp = {
					"Category": 19,
					"Explanation": "the bill focuses on how appropriated funds are reserved and managed, a matter of government budgeting and operations."
				}

			if response['id'] == 'batch_req_691e83c3ed748190869e366da03a2c8a':
				temp = {"Category": 11}
			
			if response['id'] == 'batch_req_691e1a1386708190a1c903acb68d6c9e':
				temp = {"Category": 20}
			
			if response['id'] == 'batch_req_691e1a7af54c8190b90359b6f3fa098f':
				temp = {"Category": 11}
			
			if response['id'] == 'batch_req_691e1aa192f48190b11f2ff8853ce5b9':
				temp = {"Category": 12}

			if response['id'] == 'batch_req_691e1aeea1a481908f3c2075d210aaf3':
				temp = {
					"Category": 11,
					"Confidence": 0.78
				}

			if response['id'] == 'batch_req_691e1b0735908190bd1fbb08a1b93fd3':
				temp = {
					"Category": 20,
					"Explanation": "the bill concerns modification of a public water resource project (dam construction) rather than general environment, energy, or commerce."
				}

			if response['id'] == 'batch_req_691e1b9006a08190bca7dff71ff7896b':
				temp = {
					"Category": 2,
					"Confidence": 0.88,
					"Explanation": "The bill directly concerns a major civil rights law protecting individuals with disabilities, placing it in the civil rights and liberties category."
				}

			if response['id'] == 'batch_req_691dff91b188819082286c301142595a':
				temp = {"Category": 19}

			if response['id'] == 'batch_req_691e033dad808190b22592ab3bb31d16':
				temp = {
					"Category": 19,
					"Confidence": 0.78
				}
			
			if response['id'] == 'batch_req_691e06a6f680819091bde75562172c43':
				temp = {"Category": 14}

			if response['id'] == 'batch_req_691e42e752e8819085369d818486990a':
				temp = {"Category": 14}

			if response['id'] == 'batch_req_691e072a82248190ba5801dda90b6dc2':
				temp = {"Category": 20}
			
			if response['id'] == 'batch_req_691e431609648190a150f4191bd30887':
				temp = {"Category": 19}
			
			if response['id'] == 'batch_req_691e08254a208190a9f9363fb710b4c1':
				temp = {"Category": 3}
		
			if response['id'] == 'batch_req_691e08e505d08190920312557ce6beb7':
				temp = {
					"Category": 12,
					"Confidence": 0.85,
					"Explanation": "The bill concerns modifying benefits under the Social Security Act, which is a social welfare policy matter."
				}
				
			if response['id'] == 'batch_req_691e0a121d7881908d283d258b5beabd':	
				temp = {"Category": 8}

			if response['id'] == 'batch_req_691e0a30d49c8190b868a9f731a9548b':
				temp = {"Category": 7}
				
			if response['id'] == 'batch_req_691e461f614c8190acfcf9982b49de4b':
				temp = {"Category": 20}
				
			if response['id'] == 'batch_req_691e0e6a382c81909c81d69c97f7f840':
				temp = {"Category": 20}

			if response['id'] == 'batch_req_691e10708f9c8190bca3fe83cae0793d':
				temp = {
					"Category": 4,
					"Explanation": "extends mandatory price reporting for livestock under the Agricultural Marketing Act."
				}
				
			if response['id'] == 'batch_req_691e11f9e1fc8190b805e92eaa071b22':
				temp = {"Category": 11}

			if response['id'] == 'batch_req_691e143d09d48190886d7a8fc2c498f3':
				temp = {"Category": 10}

			if response['id'] == 'batch_req_691e175d798c8190ad1af3f839dc5ccc':
				temp = {
					"Category": 10,
					"Confidence": 0.85,
					"Explanation": "The core issue is vessel registry and authorization to operate in U.S. coastwise trade, a transportation/maritime policy matter."
				}
		
			if response['id'] == 'batch_req_691e176af7848190bf23ad4b6e441a15':
				temp = {"Category": 12}
			
			if response['id'] == 'batch_req_691e178144388190968cabacb5285015':
				temp = {"Category": 17}

			if response['id'] == 'batch_req_691e17b8fa788190a343e560e68ac379':
				temp = {
					"Category": 19,
					"Explanation": "The bill is best categorized as Government Operations since it concerns compensation for executives of a federal agency."
				}

			if response['id'] == 'batch_req_691e18f54c748190a9d92f067fd1f99a':
				temp = {"Category": 12}

			if response['id'] == 'batch_req_691df4e4f8388190a0ec2f06f54e6c2e':		
				temp = {"Category": 5}

			if response['id'] == 'batch_req_691df4fc57688190a0bb21614cb4d9b4':
				temp = {"Category": 15}
				
			if response['id'] == 'batch_req_691df576d304819098a0c4c6b4e60472':
				temp = {
					"Category": 15,
					"Confidence": 0.82
				}

			if response['id'] == 'batch_req_691df58480cc8190b46c6862f7a172d7':
				temp = {"Category": 9}
				
			if response['id'] == 'batch_req_691df5d4a32481909437927e8781976f':
				temp = {
					"Category": 18,
					"Confidence": 0.68
				}

			if response['id'] == 'batch_req_691df60ed67481908037a349fa353a70':
				temp = {
					"Category": 17,
					"Confidence": 0.82,
					"Explanation": "The bill concerns tariff policy for imported chemical mixtures and adjuvants, which falls under foreign trade/commerce."
				}

			if response['id'] == 'batch_req_691e2596098881909f1a837e63b2bbca':
				temp = {"Category": 20}

			if response['id'] == 'batch_req_691e259fadbc8190b34942b0574c8d1f':
				temp = {"Category": 11}
			
			if response['id'] == 'batch_req_691df7befc208190b41b76f5b03bcf37':
				temp = {
					"Category": 20,
					"Confidence": 0.84
				}
			if response['id'] == 'batch_req_691df8e1f0ec81909f93f199490074dc':
				temp = {"Category": 10}
				
			if response['id'] == 'batch_req_691e187ff5688190b06da1629f9918d6':
				temp = {
					"Category": 19,
					"Confidence": 0.75,
					"Explanation": "The bill concerns the appointment process for CIA officials, a government operations and executive appointment matter with national security implications."
				}

			if response['id'] == 'batch_req_692089bd236c8190833d33ab35f6e088':
				temp = {"Category": 3}

			if response['id'] == 'batch_req_692097a4c4fc81908f4d3cd9e0662c90':
				temp = {
					"Category": 9,
					"Confidence": 0.98,
					"Explanation": "The bill amends the Immigration and Nationality Act to change refugee admission procedures, which directly falls under immigration policy."
				}
				
			if 'Category' in temp:
				major = int(temp["Category"])
			else:
				# major = None
				continue

			if 'Confidence' in temp:
				confidence = float(temp["Confidence"]) 
			else:
				confidence = None

			if response["AddExplanation"] and ('Explanation' in temp):
				explanation = temp["Explanation"]
			else: 
				explanation = None

		else:
			pattern = r'^(\d+)\s*[,]{0,1}\s*[\r\n]{0,1}\s*([0-9]\.[0-9]{2})\s*[,]{0,1}[\r\n]{0,1}?\s*(.*)?$'
			match = re.match(pattern, response_text)
			major = int(match.group(1))
			confidence = float(match.group(2))
			explanation = match.group(3) if response["AddExplanation"] else None
		
		responses_decoded.append({
			"ID": response["ID"],
			"MajorLLM": major,
			"MajorTextLLM": MAJOR_CODE[major] if major is not None else None,
			"ConfidenceLLM": confidence,
			"ExplanationLLM": explanation,
			"InputTokens": int(response.response["body"]["usage"]["prompt_tokens"]),
			"OutputTokens": int(response.response["body"]["usage"]["completion_tokens"])
		})
	return(pd.json_normalize(responses_decoded))

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

def create_prompts(prompting_strategies, bills):
	id = 0
	prompts = []
	for _, bill in bills.iterrows():
		for _, strategy in prompting_strategies.iterrows():
			id = id + 1
			prompt = {
				"ID": id,
				"BillID": bill["BillID"],
				"PromptingStrategyID": strategy["PromptingStrategyID"],
				"PromptingStrategyName": strategy["PromptingStrategyName"],
				"ResponseFormat": strategy["ResponseFormat"],
				"AddExplanation": strategy["AddExplanation"],
				"AddExamples": strategy["AddExamples"],
				"Model": strategy["Model"],
				"Temperature": strategy["Temperature"]
			}
			prompts.append(prompt)

	return(pd.json_normalize(prompts))

def main():
	bills = pd.read_csv(os.path.join(DATA_DIR, f"bills.csv"))

	prompting_strategies = pd.read_csv(os.path.join(DATA_DIR, "prompt_templates.csv"))
	prompts_p1 = create_prompts(prompting_strategies, bills)
	
	prompting_strategies = pd.read_csv(os.path.join(DATA_DIR, "prompt_templates_p2.csv"))
	prompts_p2 = create_prompts(prompting_strategies, bills)

	responses_dir = os.path.join(DATA_DIR, "llm/responses_batched")
	responses_path_p1 = [os.path.join(responses_dir, name) for name in os.listdir(responses_dir) if ("gpt-5" not in name)]
	responses_path_p2 = [os.path.join(responses_dir, name) for name in os.listdir(responses_dir) if ("gpt-5" in name)]
	responses_p1 = read_and_merge_jsonl_files(responses_path_p1)
	responses_p2 = read_and_merge_jsonl_files(responses_path_p2) 

	print(f"prompts_p1.shape = {prompts_p1.shape}")
	print(f"prompts_p2.shape = {prompts_p2.shape}")
	print(f"responses_p1.shape = {responses_p1.shape}")
	print(f"responses_p2.shape = {responses_p2.shape}")

	# Load and merge batched responses
	# responses = read_and_merge_jsonl_files(os.path.join(DATA_DIR, f))
	responses_p1["ID"] = responses_p1["custom_id"].apply(lambda x: int(x[3:]))
	responses_p2["ID"] = responses_p2["custom_id"].apply(lambda x: int(x[3:]))

	responses_p1 = responses_p1.merge(prompts_p1[["ID", "BillID", "ResponseFormat", "AddExplanation"]], on="ID")
	responses_p2 = responses_p2.merge(prompts_p2[["ID", "BillID", "ResponseFormat", "AddExplanation"]], on="ID")
	responses_p1.set_index("ID", inplace=True, drop=False)
	responses_p2.set_index("ID", inplace=True, drop=False)
	responses_p1.sort_index(inplace=True)
	responses_p2.sort_index(inplace=True)

	# Decoded responses and save as jsonl file
	responses_p1 = decode_responses(responses_p1)
	responses_p2 = decode_responses_p2(responses_p2)
	
	responses_p1 = prompts_p1.merge(responses_p1, on="ID", validate="1:1", how="left")
	responses_p2 = prompts_p2.merge(responses_p2, on="ID", validate="1:1", how="left")
	responses = pd.concat([responses_p1, responses_p2])

	# Merge prompts and bills metadata with llm responses
	bills_llm = responses.merge(bills, on="BillID", validate="m:1")
	# bills_llm_path = os.path.join(DATA_DIR, f"bills_llm.csv")
	# bills_llm.to_csv(bills_llm_path, index=False)
	
	bills_llm_path = os.path.join(DATA_DIR, f"bills_llm_p1.csv")
	(
		bills_llm
		.query('~Model.isin(["gpt-5-nano", "gpt-5-mini"])')
		.to_csv(bills_llm_path, index=False)
	)
	print(f"Saved {bills_llm_path}")

	bills_llm_path = os.path.join(DATA_DIR, f"bills_llm_p2.csv")
	(
		bills_llm
		.query('Model.isin(["gpt-5-nano", "gpt-5-mini"])')
		.to_csv(bills_llm_path, index=False)
	)
	print(f"Saved {bills_llm_path}")

if __name__ == "__main__":
	main()
