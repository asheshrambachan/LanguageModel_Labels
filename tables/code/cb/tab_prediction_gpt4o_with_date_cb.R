# Table: Accuracy, true positive rate (TPR), and false positive rate (FPR) of GPT-4o’s predictions on Congressional legislation, with date.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/cb") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "cb_prediction/Data/bills_llm_passage.csv") 
tab_path <- file.path(tab_dir, "tab_prediction_gpt4o_with_date_cb.tex")

# Load required packages quietly and custom functions
require(dplyr, warn.conflicts = FALSE)

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
data <- read.csv(data_path) %>%
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
  tidyr::pivot_longer(
    -c(Model, Prompt),
    names_to = c(".value", "PredictedOutcome"),
    names_sep = "\\."
  ) %>%
  relocate(PredictedOutcome, 1) %>%
  arrange(PredictedOutcome, Model, Prompt) %>%
  filter(
    Model=="GPT-4o",
    Prompt=="Prompt with date restriction"
    ) %>%
  select(!c(Prompt, Model))

# Generate latex tables
tab <- data %>% 
  rename(" "=PredictedOutcome) %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") 

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

