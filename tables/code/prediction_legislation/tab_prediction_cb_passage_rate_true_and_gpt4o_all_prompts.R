# Dec 17, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/prediction_legislation") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "prediction_legislation/data/prediction_passage_rates.csv")
tab_path <- file.path(tab_dir, "tab_prediction_cb_passage_rate_true_and_gpt4o_all_prompts.tex")

# Load required packages quietly
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Load and format data
data <- read.csv(data_path) %>%
  rename("Passage Rate"=Passage.Rate) %>%
  filter(
    Model != "GPT-3.5"
  ) %>%
  mutate(Model = factor(
    if_else(Prompt!="", sprintf("%s %s", Model, Prompt), Model),
    levels = c(
      "True",
      "GPT-4o Base prompt",
      "GPT-4o Prompt with date restriction"
    )
  ), .before=2) %>%
  arrange(Chamber, Model) %>%
  select(-c(Chamber, Prompt))

# Generate latex tables
tab <- data %>% 
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  row_spec(3, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("House", 1, 3, italic=T, bold=F)  %>%
  pack_rows("Senate", 4, 6, italic=T, bold=F)

tab <- gsub("\\\\addlinespace\\[0.3em\\]\n", "", tab)

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

