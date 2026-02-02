# Dec 16, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/prediction_legislation") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "prediction_legislation/data/completion_cosine_euclidean.csv")
tab_path <- file.path(tab_dir, "tab_completion_cosine_euclidean_gpt5mini_cb_all_prompts.tex")

# Load required packages quietly
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

data <- read.csv(data_path)  %>%
  filter(
    Model=="GPT-5-mini"
  ) %>%
  mutate(Model = factor(
    if_else(Prompt!="", sprintf("%s %s", Model, Prompt), Model),
    levels = c(
      "GPT-5-mini Base prompt",
      "GPT-5-mini Prompt with date restriction"
    )
  ), .before=1) %>%
  arrange(Metric, Model) %>%
  select(-c(Metric, Prompt))

# Generate latex tables
tab <- data %>% 
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  row_spec(2, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Cosine similarity", 1, 2, italic=T, bold=F)  %>%
  pack_rows("Euclidean distance", 3, 4, italic=T, bold=F)

tab <- gsub("\\\\addlinespace\\[0.3em\\]\n", "", tab)

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))