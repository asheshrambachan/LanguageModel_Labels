# The code is based on https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/egami_et_al/code/predict_errors.py 

import os
import re
import pandas as pd
import nltk
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report, roc_curve, auc
import matplotlib.pyplot as plt

REPO_DIR = '.'
data_dir = os.path.join(REPO_DIR, "estimation_legislation/data")
fig_dir = os.path.join(REPO_DIR, "estimation_legislation/figures")
os.makedirs(fig_dir, exist_ok=True)

nltk.download('stopwords', quiet=True)
nltk.download('wordnet', quiet=True)
STOPWORDS = nltk.corpus.stopwords.words('english')
LEMMATIZER = nltk.stem.WordNetLemmatizer()
VECTORIZER = CountVectorizer()

def clean_text(x):    
    # lowecase and remove punctuation
    x = re.sub(r'[^a-zA-Z]', ' ', x.lower())

    # remove stopwords 
    words = [word for word in x.split() if word not in set(STOPWORDS)]

    # stemming (maybe omit and see if results change?)
    words = [LEMMATIZER.lemmatize(word) for word in words]
    
    # join back into string and return (sklearn vectorizer wants string as input)
    return ' '.join(words)

def bag_of_words(x):
    # Create BOW representation    
    x_clean = x.apply(clean_text) #(x)
    return VECTORIZER.fit_transform(x_clean)

def predict_error(bills_llm, seed = 123):
    # Data Preprocessing
    X = bag_of_words(bills_llm["Description"])
    y = bills_llm["Major"] !=  bills_llm["MajorLLM"]

    # Logistic Regression
    models = bills_llm["Model"].unique()
    prompt_mods = bills_llm["PromptingStrategyID"].unique()

    regressions = []
    for model in models:
        for prompt_mod in prompt_mods:
            for regularizer in ['Lasso', 'Ridge']:
                condition = (bills_llm["Model"]==model) & (bills_llm["PromptingStrategyID"]==prompt_mod)
                X_subset = X[condition]
                y_subset = y[condition]

                X_subset_train, X_subset_test, y_subset_train, y_subset_test = train_test_split(X_subset, y_subset, test_size=0.5, random_state=seed)

                # Logistic Regression with penalty
                penalty = 'l1' if (regularizer=='Lasso') else 'l2'
                logistic_model = LogisticRegression(penalty=penalty, solver='liblinear', max_iter=1000)
                logistic_model.fit(X_subset_train, y_subset_train)

                # Evaluate 
                y_pred  = logistic_model.predict(X_subset_test) # 0 or 1
                y_probs = logistic_model.predict_proba(X_subset_test)[:,1] # prob in one hot form, get column corresponding to 1
                fpr, tpr, _ = roc_curve(y_subset_test, y_probs)

                regressions.append({
                    "Model": model,
                    "PromptModificationID": prompt_mod,
                    "Regularizer": regularizer,
                    "fpr": fpr,
                    "tpr": tpr,
                    "auc": auc(fpr, tpr),
                    "accuracy": accuracy_score(y_subset_test, y_pred),
                    "classification_report": classification_report(y_subset_test, y_pred)
                })
    return(pd.json_normalize(regressions))

def main():
    bills_llm = pd.read_csv(os.path.join(data_dir, f"bills_llm.csv"))
    regressions = predict_error(bills_llm, seed = 123)

    # AUC plots
    for model in regressions["Model"].unique():
        for regularizer in regressions["Regularizer"].unique():
            condition = (regressions["Regularizer"]==regularizer) &  (regressions["Model"]==model)
            regressions_subset = regressions[condition]
            plt.figure()
            for _, regression in regressions_subset.iterrows():
                plt.plot(regression['fpr'], regression['tpr'], label=f"Prompt Modification ID = {regression['PromptModificationID']} (AUC = {regression['auc']:0.2f})")
            plt.plot([0, 1], [0, 1], linestyle='dotted', color='black')
            plt.title(f"ROC 1{{Yhuman =/= Yllm}} for all 20 major topics\nModel: {regression['Model']}\nLogistic Regression with {regularizer} Regularizer")
            plt.xlabel('FPR')
            plt.ylabel('TPR')
            plt.legend(loc="lower right", bbox_to_anchor=(1.75, 0))
            plt.axis('equal')
            plt.ylim([0,1])
            plt.xlim([0,1])
            plt.savefig(os.path.join(fig_dir, f"ROC Plot {regression['Model']} {regression['Regularizer']}.png"), bbox_inches = "tight")
    print(f'Saved figures at {fig_dir}')

if __name__ == "__main__":
    main()        