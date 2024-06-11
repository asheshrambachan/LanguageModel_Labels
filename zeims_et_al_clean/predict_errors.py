import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import re

from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
import nltk

from sklearn.feature_extraction.text import CountVectorizer
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression, RidgeClassifier
from sklearn.metrics import accuracy_score, classification_report, roc_curve, auc

from css_mappings import DATASETS

# NLTK required downloads
nltk.download('stopwords')
nltk.download('wordnet')

def clean_text(text):

    # lowecase and remove punctuation
    text = text.lower()
    text = re.sub(r'[^a-zA-Z]', ' ', text)

    # remove stopwords 
    stop_words = set(stopwords.words('english'))
    words = text.split()
    words = [word for word in words if word not in stop_words]

    # stemming (maybe omit and see if results change?)
    lemmatizer = WordNetLemmatizer()
    words = [lemmatizer.lemmatize(word) for word in words]
    
    # join back into string (sklearn vectorizer wants string as input)
    text = ' '.join(words)
    return text

# Create BOW representation for given corpus
def bag_of_words(data):
    data['context'] = data['context'].astype(str)
    data['clean_text'] = data['context'].apply(clean_text)

    vectorizer = CountVectorizer()

    # Fit and transform the text data
    X = vectorizer.fit_transform(data['clean_text'])

    return X

# function to load dataset given dataset number
def load_dataset(index):
    dataset = DATASETS[index]
    data = pd.read_csv( dataset + '.csv')
    
    X = bag_of_words(data)
    y = data['LLM_correct']

    return X, y

#function to plot auc
def roc_plot(tpr, fpr, auc_score, model_name):
    plt.plot(fpr, tpr, label='ROC for {0} (AUC = {1:0.2f})'.format(model_name, auc_score))
    plt.plot([0, 1], [0, 1], linestyle='dotted')
    plt.xlabel('FPR')
    plt.ylabel('TPR')
    plt.legend(loc="lower right")

def main():
    lasso_auc = []
    ridge_auc = []
    for i in range(len(DATASETS)):
        X, y = load_dataset(i)
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.5, random_state=1)

        # Logistic Regression
        model = LogisticRegression(max_iter=1000)
        model.fit(X_train, y_train)

        # Logistic Regression with lasso
        lasso_model = LogisticRegression(penalty='l1', solver='liblinear', max_iter=1000)
        lasso_model.fit(X_train, y_train)

        # Logistic Regression with ridge (using instead of sklearn canned Ridge classifer)
        ridge_model = LogisticRegression(penalty='l2', solver='liblinear', max_iter=1000)
        ridge_model.fit(X_train, y_train)

        # Evaluate Log reg
        y_pred = model.predict(X_test)
        y_probs = model.predict_proba(X_test)[:,1]

        fpr, tpr, thresholds = roc_curve(y_test, y_probs)
        auc_score = auc(fpr, tpr)
        print("Logistic Regression Accuracy:", accuracy_score(y_test, y_pred))
        print("AUC:", auc_score)
        print("Classification Report:\n", classification_report(y_test, y_pred))
        
        # Evaluate lasso 
        y_pred_lasso = lasso_model.predict(X_test)
        y_probs_lasso = lasso_model.predict_proba(X_test)[:,1]

        fpr_lasso, tpr_lasso, thresholds_lasso = roc_curve(y_test, y_probs_lasso)
        auc_score_lasso = auc(fpr_lasso, tpr_lasso)
        lasso_auc.append(auc_score_lasso)
        print("Lasso Accuracy:", accuracy_score(y_test, y_pred_lasso))
        print("AUC:", auc_score_lasso)
        print("Lasso Classification Report:\n", classification_report(y_test, y_pred_lasso))

        # Evaluate ridge
        y_pred_ridge = ridge_model.predict(X_test)
        y_probs_ridge = ridge_model.predict_proba(X_test)[:,1]

        fpr_ridge, tpr_ridge, thresholds_lasso = roc_curve(y_test, y_probs_ridge)
        auc_score_ridge = auc(fpr_ridge, tpr_ridge)
        ridge_auc.append(auc_score_ridge)
        print("Ridge Accuracy:", accuracy_score(y_test, y_pred_ridge))
        print("AUC:", auc_score_ridge)
        print("Ridge Classification Report:\n", classification_report(y_test, y_pred_ridge))

    # plot auc
    # plt.figure()
    # roc_plot(tpr, fpr, auc_score=auc_score, model_name="log reg")
    # roc_plot(tpr_lasso, fpr_lasso, auc_score=auc_score_lasso, model_name="log reg w/ lasso")
    # roc_plot(tpr_ridge, fpr_ridge, auc_score=auc_score_ridge, model_name="log reg w/ ridge")
    # plt.show()

    

if __name__ == "__main__":
    main()


