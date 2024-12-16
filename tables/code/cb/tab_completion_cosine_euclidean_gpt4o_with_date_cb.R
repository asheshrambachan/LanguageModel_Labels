# Dec 16, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/cb") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
completion_data_path <- file.path(repo_dir, "cb_prediction/Data/bills_llm_completion.csv")
benchmark_data_path <- file.path(repo_dir, "cb_prediction/Data/benchmark.csv")
tab_path <- file.path(tab_dir, "tab_completion_cosine_euclidean_gpt4o_with_date_cb.tex")

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

benchmark_data <- read.csv(benchmark_data_path)

completion_data <- read.csv(completion_data_path) %>%
  mutate(
    Model = recode_factor(Model, !!!model_labels_levels),
    Prompt = recode_factor(AddIntrDate, !!!prompt_labels_levels),
    TextSimilarity = if_else(TextSimilarity=="True", 1, 0)
  ) %>%
  select(c(Model, Prompt, TextSimilarity, CosineSimilarity, EuclideanDistance))  %>%
  group_by(Model, Prompt) %>%
  summarise(
    Average.CosineSimilarity = mean(CosineSimilarity),
    Average.EuclideanDistance = mean(EuclideanDistance),
    .groups = "drop"
  ) %>%
  tidyr::pivot_longer(
    -c(Model, Prompt),
    names_to = c(".value", "Metric"),
    names_sep = "\\."
  ) %>%
  relocate(Metric, 1) %>%
  arrange(Metric, Model, Prompt) 

data <- completion_data %>%
  merge(benchmark_data, by="Metric") %>%
  mutate(Metric = if_else(Metric=="CosineSimilarity", "Cosine similarity", "Euclidean distance")) %>%
  rename("Distance"=Metric) %>%
  filter(
    Model=="GPT-4o",
    Prompt=="Prompt with date restriction"
  ) %>%
  select(!c(Model, Prompt))

# Summary Completion: Embedded Comparison
tab <- data %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") 

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))