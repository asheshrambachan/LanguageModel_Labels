# Table: Accuracy, true positive rate (TPR), and false positive rate (FPR) 
# predictions on Congressional legislation, with date.

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/prediction_legislation") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "prediction_legislation/data/prediction_accuracy.csv") 
tab_path <- file.path(tab_dir, "tab_prediction_cb_accuracy_gpt3_prompt_with_date.tex")

# Load required packages quietly
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Load and format data
data <- read.csv(data_path) %>%
  arrange(Chamber, Model, Prompt) %>%
  filter(
    Model=="GPT-3.5",
    Prompt=="Prompt with date restriction"
  ) %>%
  select(!c(Prompt, Model))

# Generate latex tables
tab <- data %>% 
  rename(" "=Chamber) %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") 

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

