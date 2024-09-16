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

month_batches = ["jan", "feb", "mar", "apr", "may", "jun", "jul", 
                 "aug", "sep", "octfirst", "octsecond", "nov", "dec"]
economic_questions = ["1", "2", "3", "4", "5"]
years = ["19"]
return_types = ["cumulative", "CAPM", "FF3"]
models = ["gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o-2024-08-06"]

prompt_types = ["base_blanks", "base_json", "persona1", "persona2", "persona3", "persona4", "cot1", "cot2", "cot3"]


