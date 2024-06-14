#!/usr/bin/python
# coding=utf-8
#
# @title: Mappings for CSS Data
"""
Needed to make some custom mappings.
"""

binary_positive_class = {
    'toxicity': 'yes',  # conversation will derail
    'humor': 'true',  # joke is funny
    'misinformation': 'a',  # headline is misinfo
    'persuasion': 'true',  # is persuasive
    'power': 'yes',  # user is admin
    'semantic_change': 'a'  # words are synonyms
}

embed_text_map = {
    'toxicity': {  # will conversation derail into personal attack?
        'no': 'normal conversation',
        'yes': 'conversation derail personal attack'},
    'discourse': {  # which type of utterance?
        'a': 'question',
        'b': 'answer',
        'c': 'agreement',
        'd': 'disagreement',
        'e': 'appreciation',
        'f': 'elaboration',
        'g': 'humor'},
    'emotion': {  # which emotion characterizes above text?
        'a': 'fear',
        'b': 'anger',
        'c': 'joy',
        'd': 'sadness',
        'e': 'love',
        'f': 'surprise'},
    'figurative_language': {  # which kind of figurative language used in hypothesis?
        'a': 'idiom',
        'b': 'metaphor',
        'c': 'sarcasm',
        'd': 'simile'},
    'hate': {  # can use class labels
        'a': 'White Grievance (frustration over a minority group’s perceived privilege and casting majority groups as the real victims of racism)',
        'b': 'Incitement to Violence (flaunting in-group unity and power or elevating known hate groups and ideologies)',
        'c': 'Inferiority Language (implies one group or individual is inferior to another, including dehumanization and toxification)',
        'd': 'Irony (the use of sarcasm, humor, and satire to attack or demean a protected class or individual)',
        'e': 'Stereotypes and Misinformation (associating a protected class with negative attributes)',
        'f': 'Threatening and Intimidation (conveys a speaker commitment to a target’s pain, injury, damage, loss, or violation of rights)'},
    'humor': {
        'false': 'not funny',
        'true': 'funny to most people'},
    'ideology_books': {  # bias lolol
        'a': 'Liberal',
        'b': 'Conservative',
        'c': 'Neutral'},
    'dialect_features': {
        "a": "Article Omission (e.g., 'Person I like most is here.')",
        "b": "Copula Omission (e.g., 'Everything busy in our life.')",
        "c": "Direct Object Pronoun Drop (e.g., 'He didn’t give me.')",
        "d": "Extraneous Article (e.g, 'Educated people get a good money.')",
        "e": "Focus Itself (e.g, 'I did it in the month of June itself.')",
        "f": "Focus Only (e.g, 'I was there yesterday only'.)",
        "g": "General Extender 'and all' (e.g, 'My parents and siblings and all really enjoy it'.)",
        "h": "Habitual Progressive (e.g., 'They are getting H1B visas.')",
        "i": "Invariant Tag 'isn’t it, no, na' (e.g., 'It’s come from me, no?')",
        "j": "Inversion In Embedded Clause (e.g., 'The school called to ask when are you going back.')",
        "k": "Lack Of Agreement (e.g., 'He talk to them.')",
        "l": "Lack Of Inversion In Wh-questions (e.g., 'What are you doing?')",
        "m": "Left Dislocation (e.g., 'My parents, they really enjoy playing board games.')",
        "n": "Mass Nouns As Count Nouns (e.g., 'They use proper grammars there.')",
        "o": "Non-initial Existential 'is / are there' (e.g., 'Every year inflation is there.')",
        "p": "Object Fronting (e.g., 'In fifteen years, lot of changes we have seen.')",
        "q": "Prepositional Phrase Fronting With Reduction (e.g., 'First of all, right side we can see a plate.')",
        "r": "Preposition Omission (e.g., 'I stayed alone two years.')",
        "s": "Resumptive Object Pronoun (e.g., 'Some teachers when I was in school I liked them very much.')",
        "t": "Resumptive Subject Pronoun (e.g., 'A person living in Calcutta, which he didn’t know Hindi earlier, when he comes to Delhi he has to learn English.')",
        "u": "Stative Progressive (e.g., 'We will be knowing how much the structure is getting deflected.')",
        "v": "Topicalized Non-argument Constituent (e.g., 'in the daytime I work for the courier service')",
        "w": "None of the above"},
    'ideology_media': {
        "a": "Left-wing article",
        "b": "Right-wing article",
        "c": "Centrist article"},
    'mrf-classification': {
        "a": "misinformation",
        "b": "trustworthy"},
    'persuasion_winning_arguments': {
        'false': 'unpersuasive',
        'true': 'persuasive'},
    'politeness': {
        'a': 'polite',
        'b': 'neutral',
        'c': 'impolite'},
    'power': {
        'no': 'powerless',
        'yes': 'powerful'},
    'persuasion_raop': {  # strategy to appeal for pizza
        "a": "Evidence (Providing concrete facts or evidence for the narrative or request, like 'There is a Pizza Hut and a Dominos near me.')",
        "b": "Politeness (The usage of polite language in requests, like 'Thank you so much!')",
        "c": "Reciprocity (Responding to a positive action with another positive action. People are more likely to help if they have received help themselves. Example messages are like 'I’ll pay it forward with my first check')",
        "d": "Impact (Emphasizing the importance or impact of the request, like 'I'll use this pizza to celebrate')",
        "e": "Emotion (Making requests full of emotional valence and arousal affect to influence others, like 'I’ve been in the lowest depressive state of my life')",
        "f": "Scarcity (People emphasizing on the urgency, rare of their needs, like 'I haven’t ate a meal in two days')",
        "g": "Other"},
    'stance': {  # stance towards trump
        "a": "Anti-Trump",
        "b": "Pro-Trump",
        "c": "Neutral towards Trump"},
    'empathy': {  # Explorations are when a mental health counselor shows active interest in a seeker by asking about unstated experiences. What level of exploration is expressed in the counselor's message above?
        "a": "Strong exploration (specifically labels the seeker’s experiences and feelings, like 'Are you feeling alone right now?')",
        "b": "Weak exploration (a generic question, like 'What happened?')",
        "c": "No exploration"},
    'semantic_change': {  # Two words mean the same thing?
        "a": "Same",
        "b": "Different"}
}

# These are copied directly from eval_significance.py to avoid requiring all of their dependencies
DATASETS = [
    "discourse",
    "toxicity",
    "power",
    "hate",
    "humor",
    "figurative_language",
    "persuasion_winning_arguments",
    "politeness",
    "ideology_media",
    "dialect_features",
    "ideology_books",
    "stance",
    "semantic_change",
    "misinformation",
    "empathy",
    "emotion",
    "persuasion_raop",
]

DATASETS_NAMES = {
    'discourse': "Discourse",
    'toxicity': "Toxicity",
    'power': "Power",
    'hate': "Hate",
    'humor': "Humor",
    'figurative_language': "Figurative Language",
    'persuasion_winning_arguments': "Persuasion \n(Winning Arguments)",
    'politeness': "Politeness",
    'ideology_media': "Ideology (Media)",
    'dialect_features': "Dialect Features",
    'ideology_books': "Ideology (Books)",
    'stance': "Stance",
    'semantic_change': "Semantic Change",
    'misinformation': "Misinformation",
    'empathy': "Empathy",
    'emotion': "Emotion",
    'persuasion_raop': "Persuasion (RAOP)",
}

MODELS = [
    "flan-t5-small",
    "flan-t5-base",
    "flan-t5-large",
    "flan-t5-xl",
    "flan-t5-xxl",
    "flan-ul2",
    "text-ada-001",
    "text-babbage-001",
    "text-curie-001",
    "text-davinci-001",
    "text-davinci-002",
    "text-davinci-003",
    "chatgpt",
]

MAPPINGS = {
    "power": {
        "true": "yes",
        "false": "no",
    },
    "persuasion": {
        "1.0": "True",
        "0.0": "False",
    },
    "toxicity": {
        "true": "yes",
        "false": "no",
    },
    "misinformation": {
        "misinformation": "A",
        "trustworthy": "B",
    },
    "politeness": {
        "1": "A",
        "0": "B",
        "-1": "C",
    },
    "figurative_language": {
        "idiom": "A",
        "metaphor": "B",
        "sarcasm": "C",
        "simile": "D",
    },
    "ideology_media": {
        "left": "A",
        "right": "B",
        "center": "C",
    },
    "semantic_change": {
        "same": "A",
        "different": "B",
    },
    "stance": {"against": "A", "favor": "B", "none": "C"},
    "ideology_books": {
        "liberal": "A",
        "conservative": "B",
        "neutral": "C",
    },
    "hate": {
        "white_grievance": "A",
        "incitement": "B",
        "inferiority": "C",
        "irony": "D",
        "stereotypical": "E",
        "threatening": "F",
    },
    "discourse": {
        "question": "A",
        "answer": "B",
        "agreement": "C",
        "disagreement": "D",
        "appreciation": "E",
        "elaboration": "F",
        "humor": "G",
    },
    "dialect_features": {
        "preposition omission": "R",
        "copula omission": "B",
        "resumptive subject pronoun": "S",
        "resumptive object pronoun": "T",
        "extraneous article": "D",
        "focus only": "F",
        "mass nouns as count nouns": "N",
        "stative progressive": "U",
        "lack of agreement": "K",
        "none of the above": "W",
        "lack of inversion in wh-questions": "L",
        "topicalized non-argument constituent": "V",
        "inversion in embedded clause": "J",
        "focus itself": "E",
        'general extender "and all"': "G",
        '"general extender ""and all"""': "G",
        "object fronting": "P",
        'invariant tag "isn’t it, no, na"': "I",
        '"invariant tag ""isn’t it, no, na"""': "I",
        "habitual progressive": "H",
        "article omission": "A",
        "prepositional phrase fronting with reduction": "Q",
        'non-initial existential "is / are there"': "O",
        '"non-initial existential ""is / are there"""': "O",
        "left dislocation": "M",
        "direct object pronoun drop": "C",
    },
}


def clean(txt, mapping={}):
    c = str(txt).replace("&", "").lower().strip()
    if c in mapping:
        return mapping[c].lower()
    elif c.endswith("."):
        return c[-1].lower()
    else:
        return c.lower()
