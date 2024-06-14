import os
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

from css_mappings import DATASETS, DATASETS_NAMES, MODELS
import seaborn as sns

# make sure we're working in this directory
script_path = os.path.abspath(__file__)
script_directory = os.path.dirname(script_path)
os.chdir(script_directory)

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
def load_dataset(dataset, model):
    data = pd.read_csv('../data/' + dataset + '.csv')
    
    X = bag_of_words(data)
    y = data[model + '_correct'].to_list()

    return X, y

# function to plot and save by model bar graphs
def auc_bar_by_model(lasso_auc_list, ridge_auc_list, dataset_list, model_name):
    fig, ax = plt.subplots()
    bar_width = 0.5
    index = np.arange(len(dataset_list))

    # Plotting scores
    bars1 = ax.bar(index, lasso_auc_list, bar_width, label='AUC Lasso')
    bars2 = ax.bar(index + bar_width, ridge_auc_list, bar_width, label='AUC Ridge')

    # Adding labels, title, and custom x-axis tick labels
    ax.set_xlabel('Labeling Task')
    ax.set_ylabel('AUC')
    ax.set_title(f'AUC by Task (Labels from {model_name})')
    ax.set_xticks(index + bar_width / 2)
    ax.set_xticklabels(dataset_list, rotation=90) 
    ax.legend()

    plt.savefig(f'../figures/auc_by_model/{model_name}_auc_by_task.png', bbox_inches='tight')

# function to plot and save heatmaps
def auc_heatmap(heatmap_array, model_type):
    df = pd.DataFrame(heatmap_array, index=DATASETS_NAMES.values(), columns=MODELS)
    plt.figure(figsize=(10, 8))
    sns.heatmap(df, annot=True, fmt=".2f", cbar=True, cmap = "rocket_r")
    plt.title(f'{model_type} Model AUC Scores')
    plt.ylabel('Datasets')
    plt.xlabel('Models')
    plt.savefig(f'../figures/heatmaps/model_with_{model_type}.png', bbox_inches='tight')

# function to plot auc
def roc_plot(tpr, fpr, auc_score, model_name):
    plt.plot(fpr, tpr, label='ROC for {0} (AUC = {1:0.2f})'.format(model_name, auc_score))
    plt.plot([0, 1], [0, 1], linestyle='dotted')
    plt.xlabel('FPR')
    plt.ylabel('TPR')
    plt.legend(loc="lower right")


def main():

    # for making figures
    heatmap_lasso = np.full((len(DATASETS), len(MODELS)), np.nan)
    heatmap_ridge = np.full((len(DATASETS), len(MODELS)), np.nan)
    results = []

    # iterate over LLMS
    for current_model in MODELS:
        # keep track of which models were used to generate labels for which tasks
        datasets_included = []
        # iterate over datasets
        for current_dataset in DATASETS:
            try:
                X, y = load_dataset(current_dataset, current_model)
                print(current_dataset)
            except:
                print("LLM labels not present for {dataset}\n".format(dataset=current_dataset))
                continue

            datasets_included.append(DATASETS_NAMES[current_dataset])
            X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.5, random_state=1)
            
            # Logistic Regression with lasso
            lasso_model = LogisticRegression(penalty='l1', solver='liblinear', max_iter=1000)
            lasso_model.fit(X_train, y_train)

            # Logistic Regression with ridge (using penalty=l2 instead of sklearn's canned Ridge classifer)
            ridge_model = LogisticRegression(penalty='l2', solver='liblinear', max_iter=1000)
            ridge_model.fit(X_train, y_train)
            
            # Evaluate lasso 
            y_pred_lasso = lasso_model.predict(X_test)
            y_probs_lasso = lasso_model.predict_proba(X_test)[:,1]

            fpr_lasso, tpr_lasso, thresholds_lasso = roc_curve(y_test, y_probs_lasso)
            auc_score_lasso = auc(fpr_lasso, tpr_lasso)
            heatmap_lasso[DATASETS.index(current_dataset), MODELS.index(current_model)] = auc_score_lasso
            # print("Lasso Accuracy:", accuracy_score(y_test, y_pred_lasso))
            # print("AUC:", auc_score_lasso)
            # print("Lasso Classification Report:\n", classification_report(y_test, y_pred_lasso))

            # Evaluate ridge
            y_pred_ridge = ridge_model.predict(X_test)
            y_probs_ridge = ridge_model.predict_proba(X_test)[:,1]
            
            fpr_ridge, tpr_ridge, thresholds_lasso = roc_curve(y_test, y_probs_ridge)
            auc_score_ridge = auc(fpr_ridge, tpr_ridge)
            heatmap_ridge[DATASETS.index(current_dataset), MODELS.index(current_model)] = auc_score_ridge
            # print("Ridge Accuracy:", accuracy_score(y_test, y_pred_ridge))
            # print("AUC:", auc_score_ridge)
            # print("Ridge Classification Report:\n", classification_report(y_test, y_pred_ridge))

            results.append((DATASETS_NAMES[current_dataset], current_model, 'Lasso', auc_score_lasso))
            results.append((DATASETS_NAMES[current_dataset], current_model, 'Ridge', auc_score_ridge))

            # ROC curves 

            # plt.figure()
            # roc_plot(tpr, fpr, auc_score=auc_score, model_name="log reg")
            # roc_plot(tpr_lasso, fpr_lasso, auc_score=auc_score_lasso, model_name="log reg w/ lasso")
            # roc_plot(tpr_ridge, fpr_ridge, auc_score=auc_score_ridge, model_name="log reg w/ ridge")
            # plt.show()

    # Figures
    # heatmaps
    auc_heatmap(heatmap_lasso, 'Lasso')
    auc_heatmap(heatmap_ridge, 'Ridge')

    # Summary dataframe. Can also turn this into a by-task bar chart
    df = pd.DataFrame(results, columns=['Dataset', 'Model', 'Method', 'AUC'])
    # df.to_csv("../results_summary_auc.csv")
    

if __name__ == "__main__":
    main()


