# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/prediction_legislation") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "prediction_legislation/data/prediction_passage_rates.csv")
tab_path <- file.path(tab_dir, "tab_prediction_cb_passage_rate_all_models_all_prompts.tex")

# Load required packages quietly
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Load and format data
data <- read.csv(data_path) %>%
  rename("Passage Rate"=Passage.Rate) %>%
  mutate(Model = factor(
    if_else(Prompt!="", sprintf("%s %s", Model, Prompt), Model),
    levels = c(
      "True",
      "GPT-3.5 Base prompt",
      "GPT-3.5 Prompt with date restriction",
      "GPT-4o Base prompt",
      "GPT-4o Prompt with date restriction",
      "GPT-5-mini Base prompt",
      "GPT-5-mini Prompt with date restriction",
      "GPT-5-nano Base prompt",
      "GPT-5-nano Prompt with date restriction"
    )
  ), .before=2) %>%
  arrange(Chamber, Model) %>%
  select(-c(Chamber, Prompt))

# Generate latex tables
tab <- data %>% 
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  row_spec(9, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("House", 1, 9, italic=T, bold=F)  %>%
  pack_rows("Senate", 10, 18, italic=T, bold=F)

tab <- gsub("\\\\addlinespace\\[0.3em\\]\n", "", tab)

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

