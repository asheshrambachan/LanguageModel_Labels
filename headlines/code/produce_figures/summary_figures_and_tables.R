library(tidyverse)
library(ggplot2)
library(stargazer)

# Reset the workspace by removing all objects
rm(list = ls())
source(file.path("./code/produce_figures/ggplot_theme.r"))

# Constants
dataset_names <- c(
  "Base: Fill in Blank", "Base: JSON", "COT: Careful", 
  "COT: Explanation", "COT: Step-by-step", "Persona: Economic Agent", 
  "Persona: Finance Expert", "Persona: Economy Expert", "Persona: Successful Trader"
)
dataset_files <- c("base_blanks", "base_json", "cot1", "cot2", 
                   "cot3", "persona1", "persona2", "persona3", "persona4")

question_levels <- c("q1", "q2", "q3", "q4", "q5")
question_labels <- c("Positive, Negative, or Neutral?", 
                     "Increase, Decrease, or Uncertain\n Change to Returns?",
                     "Increase, Decrease, or Uncertain\n Change to Returns at Time?",
                     "Increase, Decrease, or Uncertain\n Sentiment", 
                     "Increase, Decrease, or Uncertain\n Sentiment at Time")
model_levels <- c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o")
model_labels <- c("GPT-3.5", "GPT-4o-mini", "GPT-4o")
return_type <- "abnormal_CAPM"

# Function to standardize headline labels across different prompting strategies
convert_headline_type <- function(df) {
  df %>%
    mutate(
      headline.type.common = case_when(
        headline.type %in% c("positive", "increase") ~ "up",
        headline.type %in% c("negative", "decrease") ~ "down",
        headline.type %in% c("neutral", "uncertain") ~ "neutral",
        TRUE ~ NA_character_  # Handle any other unexpected values
      )
    )
}

# Calculate summary statistics for each dataset
calculate_stats <- function(df) {
  # Calculate mean, median, and standard deviation of confidence and magnitude
  stats <- df %>%
    summarize(
      across(c(confidence, magnitude), 
             list(mean = ~mean(.x, na.rm = TRUE),
                  median = ~median(.x, na.rm = TRUE),
                  sd = ~sd(.x, na.rm = TRUE)), 
             .names = "{.col}_{.fn}")
    )
  
  # Count the number of 'up', 'down', and 'neutral' labels
  counts <- df %>%
    count(headline.type.common) %>%
    pivot_wider(names_from = headline.type.common, 
                values_from = n, 
                values_fill = 0)
  
  # Combine statistics and label counts into a single data frame
  cbind(stats, counts)
}

# Initialize a list to store the combined results for all plots
all_results <- list()

# Loop over each combination of question and model
for (question in question_levels) {
  for (model in model_levels) {
    # Define the file path based on the current model and question
    path <- paste0("./data/step6_common_sample/across_models/", return_type, "/", 
                   model, "/", question, "/")
    
    # Read in data sets for various prompting strategies
    datasets <- lapply(dataset_files, function(x) read.csv(paste0(path, x, ".csv")))
    
    # Standardize headline labels across datasets
    datasets <- lapply(datasets, convert_headline_type)
    
    # Combine all datasets into a single data frame and add model/question/dataset information
    combined_df <- bind_rows(lapply(seq_along(datasets), function(i) {
      datasets[[i]] %>%
        mutate(
          Dataset = dataset_names[i],
          Model = factor(model, levels = model_levels, labels = model_labels),  # Use labels for models
          Question = factor(question, levels = question_levels, labels = question_labels)  # Use labels for questions
        )
    }))
    
    # Store the combined data for all models/questions
    all_results[[paste0(model, "_", question)]] <- combined_df
  }
}

# Combine all results into a single data frame for plotting
all_data <- bind_rows(all_results)

# Calculate frequencies for plotting
summary_results_long <- all_data %>%
  count(Model, Question, Dataset, headline.type.common) %>%
  group_by(Model, Question, Dataset) %>%
  mutate(Percentage = n / sum(n) * 100) %>%
  ungroup()

# Create a faceted plot
freq_plot <- ggplot(summary_results_long, 
                    aes(x = Dataset, y = Percentage, fill = headline.type.common)) +
  geom_bar(stat = "identity", position = "stack", color = "white") + 
  geom_hline(yintercept = 0, color = my_palette[["gray"]], size = 0.5) +
  labs(title = "Headline Labels by Prompting Strategy",
       x = "Prompting Strategy", y = "Percentage", fill = "Headline Type: "
  ) +
  facet_grid(rows = vars(Model), cols = vars(Question)) + 
  scale_fill_manual(values = my_colors_bar) +
  theme.bar 

ggsave(filename = glue("./figures/summary/label_frequency.png"), plot = freq_plot, width = 11, height = 8, units = "in")

# Plot the distribution of confidence scores across all labels
conf_plot <- ggplot(all_data, aes(x = Dataset, y = confidence)) +
  geom_boxplot(outlier.size = 0.5) +
  labs(
    title = "Boxplot of Confidence by Dataset and Prompting Strategy",
    x = "Prompting Strategy", y = "Confidence"
  ) +
  facet_grid(rows = vars(Model), cols = vars(Question)) +
  theme.boxplot 

ggsave(filename = glue("./figures/summary/conf_distribution.png"), plot = conf_plot, width = 11, height = 8, units = "in")

# Plot the distribution of confidence scores across all labels
mag_plot <- ggplot(all_data, aes(x = Dataset, y = magnitude)) +
  geom_boxplot(outlier.size = 0.5) +
  labs(
    title = "Boxplot of Magnitude by Dataset and Prompting Strategy",
    x = "Prompting Strategy", y = "Magnitude"
  ) +
  facet_grid(rows = vars(Model), cols = vars(Question)) +
  theme.boxplot 

ggsave(filename = glue("./figures/summary/mag_distribution.png"), plot = mag_plot, width = 11, height = 8, units = "in")

# Plot confidence levels by headline type using all_data
conf_split_plot <- ggplot(
  all_data %>%
    dplyr::filter(!is.na(headline.type.common)) %>%  
    pivot_longer(cols = confidence, names_to = "Metric", values_to = "Value"), 
  aes(x = Dataset, y = Value, fill = headline.type.common)
  ) +
  geom_boxplot(outlier.shape = NA, size = 0.2) +
  labs(
    title = "Confidence Label Distribution by Dataset and Headline Type",
    x = "Dataset", y = "Confidence", fill = "Headline Type"
  ) +
  scale_fill_manual(values = my_colors_bar) +
  ylim(.1, 1) +
  facet_grid(rows = vars(Model), cols = vars(Question)) +
  theme.boxplot 

ggsave(filename = glue("./figures/summary/conf_type_distribution.png"), plot = conf_split_plot, width = 12, height = 10, units = "in")

# Plot confidence levels by headline type using all_data
mag_split_plot <- ggplot(
  all_data %>%
    dplyr::filter(!is.na(headline.type.common)) %>%  
    pivot_longer(cols = magnitude, names_to = "Metric", values_to = "Value"), 
  aes(x = Dataset, y = Value, fill = headline.type.common)
) +
  geom_boxplot(outlier.shape = NA, size = 0.2) +
  labs(
    title = "Magnitude Label Distribution by Dataset and Headline Type",
    x = "Dataset", y = "Magnitude", fill = "Headline Type"
  ) +
  scale_fill_manual(values = my_colors_bar) +
  ylim(0, 1) +
  facet_grid(rows = vars(Model), cols = vars(Question)) +
  theme.boxplot 

ggsave(filename = glue("./figures/summary/mag_type_distribution.png"), plot = mag_split_plot, width = 12, height = 10, units = "in")



