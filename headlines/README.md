# Code and Data for Returns and Firm Headlines LLM exercise
## Process Description

Our data generation and processing pipeline for this exercise is this the following:

1. Merge [news headlines data](https://www.kaggle.com/datasets/miguelaenlle/massive-stock-news-analysis-db-for-nlpbacktests) about companies with their stock returns. We create 3 versions of this data set based on the type of stock returns considered:

* A dataset with **cumulative realized returns** at different fixed time horizons after the date the headline was published

* A dataset with **abnormal returns (under the CAPM model)** at different fixed time horizons after the date the headline was published

* A dataset with **abnormal returns (under the Fama-French 3 Factor model)** at different fixed time horizons after the date the headline was published

  All 3 versions of this merged data can be found in the `./data/returns_data/` folder. Within the subdirectory for each return type, the data is organized into monthly "batches."


2. For each headline in the data, generate 5 sets of prompts for 3 OpenAI LLMs (further model details found [here](https://platform.openai.com/docs/models/gpt-4o)):
 * GPT-3.5-turbo (default points to GPT-3.5-turbo-0125 trained up to Sep 2021)
 * GPT-4o-mini (default points to gpt-4o-mini-2024-07-18 trained up to Oct 2023)
 * GPT-4o (default pointed to gpt-4o-2024-05-13 in the version of the data here, but the data generating code has been updated to point to the newer gpt-4o-2024-08-06 trained up to Oct 2023). 
 
 	Each set of prompts asks a different economic question that tells the LLM to infer something about the company or its returns based on the headline.
	
	The question text can be found in `./data/prompt_templates.` In this directory, there are 2 `.txt` files for each question. One file has a version of the question that asks the LLM to respond by filling in a blank. The other version of the question asks the LLM to respond with a structured JSON object.
	
	For each headline and each economic question, we write 9 types of prompts. The first prompt type is simply the text in the fill in the blank `.txt` and the second prompt type is simply the JSON `.txt`. We then add 7 additional modifications to the JSON variation of the prompt. These modifications either 1. ask the LLM to take on a given persona, or 2. use chain-of-thought prompting. The modification text can be found in `./code/s0_constants.py`.

	 The script to generate the prompts is `./code/s1_constants.py` and the generated prompts are located in the `./data/step1_batch_prompts` directory. The prompts are organized by model, economic question, and monthly batch. Each model/question/batch file contains all 9 versions of the prompt for a given headline.

	 *Note that the month of October is split into 2 parts here since the number of headlines exceeds the maximum OpenAI batch size.

  

3. Prompt each LLM. The script for prompting is `./code/s2_batch_prompt.py`. This script submits calls to the OpenAI batch API, where the input batches are the prompt files located in `./data/step1_batch_prompts`. The responses from the API are stored in the `./data/step2_batch_responses` directory which has a similar structure to the prompt directory. For ease of checking progress and billing, we download the response files found in this directory from our OpenAI account instead of making calls to the API. However, we include a script `./code/s3_batch_status.py` that allows for getting the response file through the API.

4. Process responses by merging each response back with the headline it corresponds to (found in `./code/s4_process_responses.py`). In this step, we extract the LLM's direct response to the question and its magnitude and confidence rating for its response.

5. Merge returns back in (`./code/s5_merge_returns.py`). For each model, batch, return type, and prompting strategy, the script merges the processed responses with the original stock returns data. This data is organized under `./data/step5_merged_returns`.

6. Take a common sample of the responses within model and across model. In the within case, we join the batches for a given model/question and then across the 9 prompting strategies, take the intersection of headlines for which we have complete data (correctly formatted LLM responses and stock return info). In the across model case, for a given question, we take the intersection of headlines for which we have complete data across the 9 prompting strategies for all 3 models

7. Regress each type of return on the LLM-generated labels for the headlines.

## Repository Structure

For this particular exercise, navigate to the `headlines` folder. This is the root directory. All the scripts should be run from this directory.

The repository structure is the following:

* The `code` directory contains numbered python scripts used to write prompts, prompt each LLM, and parse the responses. The numbered scripts contain the functionality for the steps described in the section above:
	* `s0_headlines.py` defines the script to merge headlines data with relevant stock returns data. 
	* `s1_write_prompts.py` defines the script to write the prompts for each batch that we pass to the OpenAI API. Note that due to small data updates, the version of the prompts this script generates may be slightly different than the prompts found in the corresponding data folder. 
  * `s2_batch_prompt.py` makes calls to the OpenAI API and passes in the batches generated by the script above.
  * `s3_batch_status.py` can be used to get the description of a batch based on its id and also download a completed batch via the OpenAI API. We primarily used this script for testing, and instead downloaded completed batches from the OpenAI website.
  * `s4_process_responses.py` cleans the responses from the API and parses each response for the components that we prompt for (the LLM's one word response to an economic question and its magnitude and confidence scores). We check that each resopnse is in the correct format (either a fill in the blank or a JSON object as described in the corresponding prompt). We link each response to the prompt based on the `custom_id` field of the JSON object returned by the API. 
  * `s5_merge_returns.py` combines the cleaned responses with each type of stock return we are interested in. 
  * `s6_common_sample.py` contains the functionality to remove any duplicates and null responses, and then take a common sample of deduplicated headlines with valid responses. We take a common sample both within each model (so the intersection of valid responses to all 9 prompting strategies) and across model (the same intersection but for 9 strategies x 3 models). 
  * `s7_batch_metrics.py` reports the metrics on each batch (includes # of prompts, # of responses, # of empty/missing responses, # of duplicates, # of responses from the batch included in the common sample). 
  * `s8_bad_responses.py` reports a sample of responses that were poorly formatted (by sampling a response from each batch that did not parse correctly in step 4). We do this to report idiosyncrasies in LLM behavior. 
 
* The `data` directory contains numbered directories with the raw data files that are the outputs from each of the python scripts in the code directory.
	* `returns data` contains the outputs of the merge from `s0_headlines.py` in subdirectories corresponding to each return type. It also contains the raw data including the headlines data, market beta, and all data used to calculate returns. 
	* `step1_batch_prompts` contains for each model, for each question, for each month, a set of prompts in  `.jsonl`  format. (Note: 2 files are included for October due to batch size limits). 
	* `step2_batch_prompts`contains for each model, for each question, for each month, a set of LLM responses in `.jsonl` format. (Note: 2 files are included for October due to batch size limits). 
	* 	`step4_batch_prompts`contains for each model, for each question, for each month, a set of processed LLM responses in `.csv` format. 
	* 	`step5_merged_returns`contains for each return type, for each model, for each question, for each month, a directory of processed LLM responses merged with returns. Within each directory are 9 `.csv` files (each containing the responses to a particular prompt strategy and the corresponding stock returns). 
	* 	`step6_common_sample` contains 2 subdirectories. 
		* `/within_model` includes, for each question, for each model, a common sample of the headlines with correctly parsed responses for all 9 prompting strategies. 
		*  `/across_models` includes, for each question, a common sample of the headlines with correctly parsed responses for all 9 prompting strategies for all 3 models. 
	* `step7_batch_metrics` is a `.csv` batch metadata and `step8_bad_responses` is a sampling of poor (non-parseable) LLM responses as described in the code section above. 


* The `r_scripts` directory contains the R code used to run the regressions and make tables and figures.
	* The `common_sample.R` script replicates the functionality of common sample Python script. Tbh, it's a little faster but it just doesn't mesh with the rest of the pipeline
	* `summary_figures_and_tables.R` makes histograms by prompting strategy for each model and question to see the distribution of LLM responses. 
	* Within the `figures` folder,  `heatmaps.R` creates heatmaps that show the correlation across prompting stratgies for each economic question/LLM pair. The other 3 scripts in this directory run the regressions that we are interested in. 
		* `abnormal_returns.R` regresses abnormal returns under both models on LLM labels. Standard errors are clustered by firm and date.
		* `realized_returns_clustered.R` regresses realized returns under both models on LLM labels. Standard errors are clustered by firm and date.
		*  `realized_returns_robust.R` regresses realized returns under both models on LLM labels. Heteroskedasticity robust SEs are reported. 

## Using this Code Base
There are four possible levels of replication that this code base allows for described in decreasing complexity. 
1. Creating the dataset of headlines and returns followed by items 2-4 below.
2. Rerunning the prompting exercise by writing prompts and prompting each LLM followed by items 3 and 4 below. 
3.   Analyzing each LLMs responses to the prompting exercise and generating the regression figures and tables.
4. Generating the regression tables and figures

### Recreating the Headlines Dataset:

 - Navigate to the `./returns_data` directory. Unzip all the `.zip` files. Set the working directory to `./headlines`. Then, run `s0_headlines.py`. 
 
 ### Prompting Exercise
 - Run `s0_headlines.py`

### Analysis
- Run `./code/run_all.py` 

### Figures and Tables