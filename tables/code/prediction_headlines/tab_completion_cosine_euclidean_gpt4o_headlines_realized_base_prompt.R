# Dec 16, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/prediction_headlines") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "prediction_headlines/Data/completion_cosine_euclidean.csv")
tab_path <- file.path(tab_dir, "tab_completion_cosine_euclidean_gpt4o_headlines_realized_base_prompt.tex")

# Load required packages quietly
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

data <- read.csv(data_path)  %>%
  rename("Distance"=Metric) %>%
  filter(
    Model=="GPT-4o",
    Prompt=="Base prompt"
  ) %>%
  select(!c(Model, Prompt))

# Summary Completion: Embedded Comparison
tab <- data %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") 

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))