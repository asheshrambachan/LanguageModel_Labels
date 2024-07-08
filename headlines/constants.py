MODEL = "gpt-3.5-turbo"
API_KEY = "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"

TEMPERATURE = 1
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

explanation = "\n{explanation (less than 25 words)}"