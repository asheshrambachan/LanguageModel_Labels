# Dec 17, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "."
data_dir <- file.path(repo_dir, "prediction_headlines/data")

# Data and figure paths
data_path <- file.path(data_dir, "headlines_completion.csv")
benchmark_data_path <- file.path(repo_dir, "prediction_headlines/data/benchmark.csv")

completion_exact_examples_path <- file.path(data_dir, "completion_exact_examples.csv")
completion_exact_rates_path <- file.path(data_dir, "completion_exact_rates.csv")
completion_cosine_euclidean_path <-  file.path(data_dir, "completion_cosine_euclidean.csv")

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(logger, warn.conflicts = FALSE)

# Factor labels and levels
prompt_labels_levels <- c(
  "False"="Base prompt", 
  "True"="Prompt with date restriction"
)
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o",
  "gpt-4o-mini-2024-07-18"="GPT-4o-mini",
  "gpt-5-mini"="GPT-5-mini",
  "gpt-5-nano"="GPT-5-nano"
)

# Load and format data
data <- read.csv(data_path) %>%
  mutate(
    Model = recode_factor(model, !!!model_labels_levels),
    Prompt = recode_factor(add_date, !!!prompt_labels_levels),
    TextSimilarity = if_else(TextSimilarity=="True", 1, 0)
  ) 
benchmark_data <- read.csv(benchmark_data_path)

# Examples of completion with exact text output
completion_exact_examples <- data %>%
  filter(TextSimilarity==1) %>%
  select(c(Model, Prompt, headline_clean, headline_llm_clean))

# Place samples used in paper and slides at the top
index_first <- c(237, 9, 109, 189, 136, 176, 243, 15, 30, 55, 59)
index_last <- (1:nrow(completion_exact_examples))[-index_first]
index <- c(index_first, index_last)
completion_exact_examples <- completion_exact_examples[index, ] 
write.csv(completion_exact_examples, completion_exact_examples_path, row.names=FALSE)
log_info("Saved {completion_exact_examples_path}")

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
log_info("Saved {completion_exact_rates_path}")

# Similarity using embeddings
completion_cosine_euclidean <- data %>%
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
  arrange(Metric, Model, Prompt) %>%
  merge(benchmark_data, by="Metric") %>%
  mutate(Metric = if_else(Metric=="CosineSimilarity", "Cosine similarity", "Euclidean distance")) 
write.csv(completion_cosine_euclidean, completion_cosine_euclidean_path, row.names=FALSE)
log_info("Saved {completion_cosine_euclidean_path}")
