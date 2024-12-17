# Dec 16, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/prediction_cb") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "prediction_cb/Data/completion_exact_rates.csv")
tab_path <- file.path(tab_dir, "tab_completion_exact_rates_cb.tex")

# Load required packages quietly and custom functions
require(dplyr, warn.conflicts = FALSE)

# Load data
data <- read.csv(data_path) %>% 
  mutate(Model = factor(
    if_else(Prompt!="", sprintf("%s %s", Model, Prompt), Model),
    levels = c(
      "GPT-3.5 Base prompt",
      "GPT-3.5 Prompt with date restriction",
      "GPT-4o Base prompt",
      "GPT-4o Prompt with date restriction"
    )
  ), .before=1) %>%
  arrange(Model) %>%
  select(-Prompt)

# Generate latex tables
tab <- data %>% 
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  row_spec(2, hline_after = TRUE, extra_latex_after = "%") 

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))