MODEL = "gpt-3.5-turbo"
API_KEY = "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"

TEMPERATURE = 0
NUM_RESPONSES = 1
SYSTEM_PROMPT = ""

personas = [
    "You are a knowledgeable economic agent. ",
    "Answer this question as if you are an expert in finance. ",
    "Answer this question as if you are an expert in the economy. ",
    "Answer this question as if you were very knowledgeable about financial matters and in particular the stock market. So you are as knowledgeable as an analyst or trader at a very successful Wall Street Firm. "
]

thought_modifiers = [
    "Think carefully. ",
    "Please provide an explanation for your answer. "
]

explanation = '\n____ fill in with explanation (less than 25 words)'
explanation_json = ',\n"explanation": once sentence explanation for your headline type answer}'

batch_template = '{"custom_id": %s, "method": "POST", "url": "/v1/chat/completions", "body": {"model": "gpt-3.5-turbo-0125", "messages": [{"role": "user", "content": %s}],"temperature": 0}}'