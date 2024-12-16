# Table: Accuracy, true positive rate (TPR), and false positive rate (FPR) of GPT-4o’s predictions on Congressional legislation.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
tab_dir <- file.path(repo_dir, "Tables") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "Data/Prediction/bills_llm_passage.csv") 
tab_a_path <- file.path(tab_dir, "tab01a_cb_pass_prediction_gpt4o_without_date.tex")
tab_b_path <- file.path(tab_dir, "tab01b_cb_pass_prediction_gpt4o_with_date.tex")

# Load required packages quietly and custom functions
require(dplyr, warn.conflicts = FALSE)

# Factor labels and levels
prompt_labels_levels <- c(
  "False"="w/o date restriction", 
  "True"="w/ date restriction"
)
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o"
)

# Load data
data <- read.csv(data_path) %>%
  rename("Prompt"=AddIntrDate) %>%
  mutate(
    Model = recode_factor(Model, !!!model_labels_levels),
    Prompt = recode_factor(Prompt, !!!prompt_labels_levels)
  ) %>%
  filter(Model=="GPT-4o") %>%
  select(Model, Prompt, PassS, PassH, PassSLLM, PassHLLM) %>% 
  group_by(Model, Prompt) %>%
  summarize(
    Accuracy.Senate = mean(PassS==PassSLLM),
    TPR.Senate = sum(PassS==1 & PassSLLM==1) / sum(PassS==1),
    FPR.Senate = sum(PassS==0 & PassSLLM==1) / sum(PassS==0),
    Accuracy.House = mean(PassH==PassHLLM),
    TPR.House = sum(PassH==1 & PassHLLM==1) / sum(PassH==1),
    FPR.House = sum(PassH==0 & PassHLLM==1) / sum(PassH==0),
    .groups="drop"
  ) %>%
  mutate(id = row_number(), .before=1) %>%
  tidyr::pivot_longer(
    -c(id, Model, Prompt),
    names_to = c(".value", "Chamber"),
    names_sep = "\\.") %>%
  select(-id) %>%
  relocate(Chamber, 1) %>%
  arrange(Chamber, Model, Prompt) %>%
  select(Chamber, Prompt, Accuracy, TPR, FPR) 

# Generate latex tables
# Panel (a)
tab_a <- data %>% 
  filter(Prompt=="w/o date restriction") %>%
  select(!Prompt)  %>%
  rename(" "=Chamber) %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") 

# Panel (b)
tab_b <- data %>% 
  filter(Prompt=="w/ date restriction") %>%
  select(!Prompt)  %>%
  rename(" "=Chamber) %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") 

# Save tables
save_kable(tab_a, file = tab_a_path)
cat(sprintf("Saved %s\n", tab_a_path))
save_kable(tab_b, file = tab_b_path)
cat(sprintf("Saved %s\n", tab_b_path))

