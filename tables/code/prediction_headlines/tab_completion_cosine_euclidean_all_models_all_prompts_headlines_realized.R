# Dec 16, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/prediction_headlines") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "prediction_headlines/Data/completion_cosine_euclidean.csv")
tab_path <- file.path(tab_dir, "tab_completion_cosine_euclidean_all_models_all_prompts_headlines_realized.tex")

# Load required packages quietly
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

data <- read.csv(data_path)  %>%
  mutate(Model = factor(
    if_else(Prompt!="", sprintf("%s %s", Model, Prompt), Model),
    levels = c(
      "GPT-3.5 Base prompt",
      "GPT-3.5 Prompt with date restriction",
      "GPT-4o Base prompt",
      "GPT-4o Prompt with date restriction",
      "GPT-4o-mini Base prompt",
      "GPT-4o-mini Prompt with date restriction",
      "GPT-5-mini Base prompt",
      "GPT-5-mini Prompt with date restriction",
      "GPT-5-nano Base prompt",
      "GPT-5-nano Prompt with date restriction"
    )
  ), .before=1) %>%
  arrange(Metric, Model) %>%
  select(-c(Metric, Prompt))

# Generate latex tables
tab <- data %>% 
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  row_spec(10, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Cosine similarity", 1, 10, italic=T, bold=F)  %>%
  pack_rows("Euclidean distance", 11, 20, italic=T, bold=F)

tab <- gsub("\\\\addlinespace\\[0.3em\\]\n", "", tab)

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))