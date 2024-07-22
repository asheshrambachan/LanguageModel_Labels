library(dplyr)
# library(tidyr)
# library(ggplot2)
# library(stargazer)
# library(caret)

repo_dir = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills"
setwd(repo_dir)

# # setting seed to reproduce for now 
# set.seed(1)

# # set the file name and label type based on the above values
# filename = ifelse(balanced, "balanced", "imbalanced")
# label_type = ifelse(zeroshot, "q_gpt3_0shot", "q_gpt3_5shot")

# read in the data
data = read.csv("02_llm/prompts_and_responses_10000.csv")

# # convert columns to numeric
# data <- data %>%
#   mutate(
#     senate = as.integer(senate == "True"),
#     label = as.integer(label == "True"),
#     democrat = as.integer(democrat == "True"),
#     Postal = as.factor(Postal),
#     !!label_type := as.integer(.[[label_type]] == "True")
#   )
# 
# split data into 50-50 train/test set
test_train_ratio <- 0.7
train_indices <- sample(nrow(data), floor(test_train_ratio * nrow(data)))
train <- data[train_indices, ]
test <- data[-train_indices, ]

# get f* models for each feature V
data
chamber <- lm(label ~ senate, data = train)
party <- lm(label ~ democrat, data = train)
score <- lm(label ~ dw1, data = train)
dist <- lm(label ~ dist_macro, data = train)

