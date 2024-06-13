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
    data = pd.read_csv(dataset + '.csv')
    
    X = bag_of_words(data)
    y = data[model + '_correct'].to_list()

    return X, y

#function to plot auc
def roc_plot(tpr, fpr, auc_score, model_name):
    plt.plot(fpr, tpr, label='ROC for {0} (AUC = {1:0.2f})'.format(model_name, auc_score))
    plt.plot([0, 1], [0, 1], linestyle='dotted')
    plt.xlabel('FPR')
    plt.ylabel('TPR')
    plt.legend(loc="lower right")

def auc_bar_graph(lasso_auc_list, ridge_auc_list, dataset_list, model_name):
    fig, ax = plt.subplots()
    bar_width = 0.5
    index = np.arange(len(dataset_list))

    # Plotting scores
    if lasso_auc_list is not None:
        bars1 = ax.bar(index, lasso_auc_list, bar_width, label='AUC Lasso')
    if ridge_auc_list is not None:
        bars2 = ax.bar(index + bar_width, ridge_auc_list, bar_width, label='AUC Ridge')

    # Adding labels, title, and custom x-axis tick labels
    ax.set_xlabel('Labeling Task')
    ax.set_ylabel('AUC')
    ax.set_title(f'AUC by Task (Labels from {model_name})')
    ax.set_xticks(index + bar_width / 2)
    ax.set_xticklabels(dataset_list, rotation=90) 
    ax.legend()

    plt.savefig(f'./figures/auc_by_task/{model_name}_auc_by_task.png', bbox_inches='tight')

def main():
    heatmap_lasso = np.empty((len(DATASETS), len(MODELS)))
    heatmap_ridge = np.empty((len(DATASETS), len(MODELS)))
    heatmap_lasso[:] = np.NaN
    heatmap_ridge[:] = np.NaN

    for current_model in MODELS:
        lasso_auc_list = []
        ridge_auc_list = []
        datasets_included = []
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

            # Logistic Regression with ridge (using instead of sklearn canned Ridge classifer)
            ridge_model = LogisticRegression(penalty='l2', solver='liblinear', max_iter=1000)
            ridge_model.fit(X_train, y_train)
            
            # Evaluate lasso 
            y_pred_lasso = lasso_model.predict(X_test)
            y_probs_lasso = lasso_model.predict_proba(X_test)[:,1]

            fpr_lasso, tpr_lasso, thresholds_lasso = roc_curve(y_test, y_probs_lasso)
            auc_score_lasso = auc(fpr_lasso, tpr_lasso)
            lasso_auc_list.append(auc_score_lasso)
            print("Lasso Accuracy:", accuracy_score(y_test, y_pred_lasso))
            print("AUC:", auc_score_lasso)
            print("Lasso Classification Report:\n", classification_report(y_test, y_pred_lasso))

            # Evaluate ridge
            y_pred_ridge = ridge_model.predict(X_test)
            y_probs_ridge = ridge_model.predict_proba(X_test)[:,1]

            fpr_ridge, tpr_ridge, thresholds_lasso = roc_curve(y_test, y_probs_ridge)
            auc_score_ridge = auc(fpr_ridge, tpr_ridge)
            ridge_auc_list.append(auc_score_ridge)
            print("Ridge Accuracy:", accuracy_score(y_test, y_pred_ridge))
            print("AUC:", auc_score_ridge)
            print("Ridge Classification Report:\n", classification_report(y_test, y_pred_ridge))

            heatmap_lasso[DATASETS.index(current_dataset), MODELS.index(current_model)] = auc_score_lasso
            heatmap_ridge[DATASETS.index(current_dataset), MODELS.index(current_model)] = auc_score_ridge
        
    df_lasso = pd.DataFrame(heatmap_lasso, index=DATASETS_NAMES.values(), columns=MODELS)
    df_ridge = pd.DataFrame(heatmap_ridge, index=DATASETS_NAMES.values(), columns=MODELS)

    # Plotting Lasso Heatmap
    plt.figure(figsize=(9,8))
    sns.heatmap(df_lasso, annot = True, cmap='rocket_r', cbar=True, annot_kws={'color': 'white', 'size': 7})
    plt.title('AUC for LLM Label Predictions (Model with Lasso)')
    plt.ylabel('Datasets')
    plt.xlabel('Models')
    plt.show()

    # Plotting Ridge Heatmap
    plt.figure(figsize=(9,8))
    sns.heatmap(df_ridge, annot = True, cmap='rocket_r', cbar=True, annot_kws={'color': 'white', 'size': 7})
    plt.title('AUC for LLM Label Predictions (Model with Ridge)')
    plt.ylabel('Datasets')
    plt.xlabel('Models')
    plt.show()
        # auc_bar_graph(lasso_auc, ridge_auc, datasets_included, current_model)
        # auc_bar_graph(None, ridge_auc, datasets_included, current_model)

    # plot auc
    # plt.figure()
    # roc_plot(tpr, fpr, auc_score=auc_score, model_name="log reg")
    # roc_plot(tpr_lasso, fpr_lasso, auc_score=auc_score_lasso, model_name="log reg w/ lasso")
    # roc_plot(tpr_ridge, fpr_ridge, auc_score=auc_score_ridge, model_name="log reg w/ ridge")
    # plt.show()

    


if __name__ == "__main__":
    main()


