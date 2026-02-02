# Dec 18, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/prediction_legislation") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "prediction_legislation/data/completion_exact_examples.csv")
tab_path <- file.path(tab_dir, "tab_completion_exact_examples_cb.tex")

# Load required packages quietly
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Load and format
data <- read.csv(data_path) %>%
  rename(
    "Original Bill"=DescriptionClean,
    "LLM"=DescriptionLLMClean
  )

# Generate latex tables
tab <- data %>%
  kable(digits=3, linesep = "", booktabs=T, format = "latex", longtable = TRUE, row.names = FALSE) %>%
  kable_styling(latex_options = c("hold_position", "repeat_header")) %>%
  column_spec(1:2, width = "1.4cm") %>%
  column_spec(3:4, width = "5.5cm") 

# Save table
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))
