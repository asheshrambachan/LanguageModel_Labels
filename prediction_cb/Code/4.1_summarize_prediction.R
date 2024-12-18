# Dec 17, 2024

# Removing all objects
rm(list = ls())

# Setup directories
# repo_dir <- "~/Documents/LanguageModel_Labels"
repo_dir <- "."
data_dir <- file.path(repo_dir, "prediction_cb/data") 

# Data and table paths
bills_data_path <- file.path(data_dir, "bills.csv")
data_path <- file.path(data_dir, "bills_llm_passage.csv") 
prediction_passage_rates_path <- file.path(data_dir, "prediction_passage_rates.csv")
prediction_accuracy_path <- file.path(data_dir, "prediction_accuracy.csv")

# Load required packages quietly
suppressPackageStartupMessages({
  library(tidyr)
  library(dplyr)
})

# Factor labels and levels
prompt_labels_levels <- c(
  "False"="Base prompt", 
  "True"="Prompt with date restriction"
)
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o"
)

# Load and format data
true_rates <- read.csv(bills_data_path) %>%
  mutate(
    Senate=PassS,
    House=PassH,
    Model = "True",
    Prompt = ""
  ) %>%
  select(c(Model, Prompt, Senate, House)) %>%
  pivot_longer(
    cols = c(Senate, House), 
    names_to = "Chamber", 
    values_to = "Pass"
  ) %>%
  group_by(Chamber, Model, Prompt) %>%
  summarize(
    "Passage Rate" = mean(Pass),
    .groups="drop"
  ) 

llm_rates <- read.csv(data_path) %>%
  mutate(
    Senate=PassSLLM,
    House=PassHLLM,
    Model = recode_factor(Model, !!!model_labels_levels),
    Prompt = recode_factor(AddIntrDate, !!!prompt_labels_levels)
  ) %>%
  select(c(Model, Prompt, Senate, House)) %>%
  pivot_longer(
    cols = c(Senate, House), 
    names_to = "Chamber", 
    values_to = "Pass"
  ) %>%
  group_by(Chamber, Model, Prompt) %>%
  summarize(
    "Passage Rate" = mean(Pass),
    .groups="drop"
  ) 

prediction_passage_rates <- bind_rows(true_rates, llm_rates)
write.csv(prediction_passage_rates, prediction_passage_rates_path, row.names=FALSE)
cat(sprintf("Saved %s\n", prediction_passage_rates_path))

# Load and format data
prediction_accuracy <- read.csv(data_path) %>%
  mutate(
    Model = recode_factor(Model, !!!model_labels_levels),
    Prompt = recode_factor(AddIntrDate, !!!prompt_labels_levels)
  ) %>%
  group_by(Model, Prompt) %>%
  summarize(
    `Accuracy.Senate` = mean(PassS==PassSLLM),
    `TPR.Senate` = sum(PassS==1 & PassSLLM==1) / sum(PassS==1),
    `FPR.Senate` = sum(PassS==0 & PassSLLM==1) / sum(PassS==0),
    `Accuracy.House` = mean(PassH==PassHLLM),
    `TPR.House` = sum(PassH==1 & PassHLLM==1) / sum(PassH==1),
    `FPR.House` = sum(PassH==0 & PassHLLM==1) / sum(PassH==0),
    .groups="drop"
  ) %>%
  pivot_longer(
    -c(Model, Prompt),
    names_to = c(".value", "Chamber"),
    names_sep = "\\."
  ) 

write.csv(prediction_accuracy, prediction_accuracy_path, row.names=FALSE)
cat(sprintf("Saved %s\n", prediction_accuracy_path))
