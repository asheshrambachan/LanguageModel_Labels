# Dec 17, 2024

# Removing all objects
rm(list = ls())

# Setup directories
# repo_dir <- "~/Documents/LanguageModel_Labels"
repo_dir <- "."
data_dir <- file.path(repo_dir, "prediction_legislation/data")

# Data and figure paths
data_path <- file.path(data_dir, "bills_completion.csv")
benchmark_data_path <- file.path(repo_dir, "prediction_legislation/data/benchmark.csv")

completion_exact_examples_path <- file.path(data_dir, "completion_exact_examples.csv")
completion_exact_rates_path <- file.path(data_dir, "completion_exact_rates.csv")
completion_cosine_euclidean_path <-  file.path(data_dir, "completion_cosine_euclidean.csv")

# Load required packages quietly
suppressPackageStartupMessages({
  library(tidyr)
  library(dplyr)
})

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
    Prompt = recode_factor(AddIntrDate, !!!prompt_labels_levels),
    TextSimilarity = if_else(TextSimilarity=="True", 1, 0)
  ) 
benchmark_data <- read.csv(benchmark_data_path)

# Examples of completion with exact text output
completion_exact_examples <- data %>%
  filter(TextSimilarity==1) %>%
  select(c(Model, Prompt, DescriptionClean, DescriptionLLMClean))

# Place samples used in paper and slides at the top
index_first <- c(626, 239, 574, 306, 257, 401)
index_last <- (1:nrow(completion_exact_examples))[-index_first]
index <- c(index_first, index_last)
completion_exact_examples <- completion_exact_examples[index, ] 
write.csv(completion_exact_examples, completion_exact_examples_path, row.names=FALSE)
cat(sprintf("Saved %s\n", completion_exact_examples_path))

# Rates of exact completion
completion_exact_rates <- data %>%
  select(c(Model, Prompt, TextSimilarity))  %>%
  group_by(Model, Prompt) %>%
  summarise(
    Share = mean(TextSimilarity),
    Count = sum(TextSimilarity),
    .groups = "drop"
  ) 
write.csv(completion_exact_rates, completion_exact_rates_path, row.names=FALSE)
cat(sprintf("Saved %s\n", completion_exact_rates_path))

# Similarity using embeddings
completion_cosine_euclidean <- data %>%
  select(c(Model, Prompt, TextSimilarity, CosineSimilarity, EuclideanDistance))  %>%
  group_by(Model, Prompt) %>%
  summarise(
    Average.CosineSimilarity = mean(CosineSimilarity),
    Average.EuclideanDistance = mean(EuclideanDistance),
    .groups = "drop"
  ) %>%
  pivot_longer(
    -c(Model, Prompt),
    names_to = c(".value", "Metric"),
    names_sep = "\\."
  ) %>%
  relocate(Metric, 1) %>%
  arrange(Metric, Model, Prompt) %>%
  merge(benchmark_data, by="Metric") %>%
  mutate(Metric = if_else(Metric=="CosineSimilarity", "Cosine similarity", "Euclidean distance")) 
write.csv(completion_cosine_euclidean, completion_cosine_euclidean_path, row.names=FALSE)
cat(sprintf("Saved %s\n", completion_cosine_euclidean_path))
