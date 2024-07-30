MODEL = "gpt-4o-mini"
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

batch_template = {
                    "custom_id": "%s",
                    "method": "POST", 
                    "url": "/v1/chat/completions", 
                    "body": 
                        {
                            "model": MODEL, 
                            "messages": 
                                [{
                                    "role": "user",
                                    "content": "%s"
                                }],
                            "temperature": 0
                        }
                    }
