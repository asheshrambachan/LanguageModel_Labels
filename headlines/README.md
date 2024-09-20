# Code and Data for Returns and Firm Headlines LLM exercise

## Process Description 

Our data generation and processing pipeline for this exercise is this the following:

1. Merge news headlines data about companies with their stock returns. We create 3 versions of this data set based on the type of stock returns considered

	* A dataset with **cumulative realized returns** at different fixed time horizons after the date the headline was published

	* A dataset with **abnormal returns (under the CAPM model)** at different fixed time horizons after the date the headline was published

	* A dataset with **abnormal returns (under the Fama-French 3 Factor model)** at different fixed time horizons after the date the headline was published

	All 3 versions of this merged data can be found in the `./data/returns_data/` folder. Within the subdirectory for each return type, the data is organized into monthly "batches." Note that the month of October is split into 2 batches (because of OpenAI batch size constraints).

2. For each headline in the data, generate 5 sets of prompts for 3 LLMs (GPT-3.5-turbo, GPT-4o, and GPT-4o-mini). Each set of prompts asks a different economic question that tells the LLM to infer something about the company or its returns based on the headline.

	The question text  can be found in `./data/prompt_templates.` In this directory, there are 2 `.txt` files for each question. One file has a version of the question that asks the LLM to respond by filling in a blank. The other version of the question asks the LLM to respond with a structured JSON object.

	For each headline and each economic question, we write 9 types of prompts. The first prompt type is simply the text in the fill in the blank `.txt` and the second prompt type is simply the JSON `.txt`.  We then add 7 additional modifications to the JSON variation of the prompt. These modifications either 1. ask the LLM to take on a given persona, or 2. use chain-of-thought prompting. The modification text can be found in `./code/s0_constants.py`. 

	The script to generate the prompts is `./code/s1_constants.py` and the generated prompts are located in the `./data/step1_batch_prompts` directory. The prompts are organized by model, economic question, and monthly batch. Each model/question/batch file contains all 9 versions of the prompt for a given headline.

3. Prompt each LLM. The script for prompting is `./code/s2_batch_prompt.py`. This script submits calls to the OpenAI batch API, where the input batches are the prompt files located in `./data/step1_batch_prompts`. The responses from the API are stored in the `./data/step2_batch_responses` directory which has a similar structure to the prompt directory. For ease of checking progress and billing, we download the response files found in this directory from our OpenAI account instead of making calls to the API. However, we include a script `./code/s3_batch_status.py` that allows for getting the response file through the API.

4. Process responses by merging each response back with the headline it corresponds to (found in `./code/s4_process_responses.py`). In this step, we extract the LLM's direct response to the question and its magnitude and confidence rating for its response. 

5. Merge returns back in (`./code/s5_merge_returns.py`). For each model, batch, return type, and prompting strategy, the script merges the processed responses with the original stock returns data. This data is organized under `./data/step5_merged_returns`. 

6. Take a common sample of the responses within model and across model. In the within case, we join the batches for a given model/question and then across the 9 prompting strategies, take the intersection of headlines for which we have complete data (correctly formatted LLM responses and stock return info). In the across model case, for a given question, we take the intersection of headlines for which we have complete data across the 9 prompting strategies for all 3 models 

7. Regress each type of return on the LLM-generated labels for the headlines. 

## Repository Structure

For this particular exercise, navigate to the `headlines` folder. This is the root directory. All the scripts should be run from this directory.

The repository structure is the following:

* The `code` directory contains numbered python scripts used to write prompts, prompt each LLM, and parse the responses

* The `data` directory contains numbered directory with the raw data files that are the generated outputs from each of the python scripts in the code directory.

* The `r_scripts` directory contains the R code used to run the regressions and make tables and figures.

  

## Using this Code Base
  

For 3 LLMs, (GPT-3.5-turbo, GPT-4o, and GPT-4o-mini) write prompts that ask the model

There are four possible levels of replication that this code base allows for.

1. If you are only interested in generating the regression tables and figures

2. If you are interested in our analysis of each LLMs responses and generating t

2 sets of instructions

* create news headlines data

* if you want to rerun prompting

* if you want to rerun the processing

* if you only want to reproduce figures and tables

1. s1 and s2 (and data folder 1 and 2) have our prompting ...

  

API_KEY security note