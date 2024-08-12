#!/bin/bash

# don't include ~/
FILES_TO_COPY='
Documents/LanguageModel_Labels/congressional_bills/02_llm/bills_prompts_responses_10000.csv 
Documents/LanguageModel_Labels/congressional_bills/04_simulation/combinations_lhs.csv
Documents/LanguageModel_Labels/congressional_bills/04_simulation/simulate_lhs_parallel.R
'

cd ~/.
rsync -R $FILES_TO_COPY "$1:~/."
