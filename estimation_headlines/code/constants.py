API_KEY = "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"

personas = [
    "You are a knowledgeable economic agent. ",
    "Answer this question as if you are an expert in finance. ",
    "Answer this question as if you are an expert in the economy. ",
    "Answer this question as if you were very knowledgeable about financial matters and in particular the stock market. So you are as knowledgeable as an analyst or trader at a very successful Wall Street Firm. "
]

thought_modifiers = [
    "Think carefully. ",
    "Please provide an explanation for your answer. ",
    "Think step by step. Lay out each step. "
]

explanation = '\n____ fill in with explanation (less than 25 words)'
explanation_json = ',\n"explanation": one sentence explanation for your headline type answer}'

economic_questions = ["1", "2", "3", "4", "5"]
return_types = ["realized", "abnormal_CAPM"]
years = ["19"]
month_batches = ["jan", "feb", "mar", "apr", "may", "jun", 
                 "jul", "aug", "sep", "oct", "nov", "dec"]
models = ["gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o"]
prompt_types = ["base_blanks", "base_json", "persona1", "persona2", 
                "persona3", "persona4", "cot1", "cot2", "cot3"]

prompts_path = "./data/prompt_templates"
step0_path = "./data/step0_returns_data"
step1_path = "./data/step1_batch_prompts"
step2_path = "./data/step2_batch_ids"
step3_path = "./data/step3_batch_responses"
step4_path = "./data/step4_processed_responses"
step5_path = "./data/step5_merged_returns"
step6_path = "./data/step6_common_sample"
step7_path = "./data/step7_batch_metrics"
step8_path = "./data/step8_bad_responses"
