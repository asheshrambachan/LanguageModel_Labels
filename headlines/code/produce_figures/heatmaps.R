library(dplyr)
library(ggplot2)
library(viridis)
library(glue)

rm(list = ls())
setwd()
source(file.path("./ggplot_theme.r"))

# Define constants
question_levels <- c("q1", "q2", "q3", "q4", "q5")
question_labels <- c("Positive, Negative, or Neutral?", 
                     "Increase, Decrease, or Uncertain Change to Returns?",
                     "Increase, Decrease, or Uncertain Change to Returns at Time?",
                     "Increase, Decrease, or Uncertain Sentiment", 
                     "Increase, Decrease, or Uncertain Sentiment at Time")
question_label_map <- setNames(question_labels, question_levels)

model_levels <- c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o")
model_labels <- c("GPT-3.5", "GPT-4o-mini", "GPT-4o")
model_label_map <- setNames(model_labels, model_levels)

prompt_types <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", 
                  "persona1", "persona2", "persona3", "persona4")
prompt_type_labels <- c("Base: Fill in Blank", "Base: JSON",
                        "COT: Careful", "COT: Explanation",
                        "COT: Step-by-step", "Persona: Economic Agent",
                        "Persona: Finance Expert", "Persona: Economy Expert",
                        "Persona: Successful Trader")

return_types <- c("realized", "abnormal_CAPM", "abnormal_FF3")
return_labels <- c("Realized Returns", "Abnormal Returns (CAPM)", "Abnormal Returns (FF3)")
return_label_map <- setNames(return_labels, return_types)

# Helper function to read datasets
read_datasets <- function(path, prompt_types) {
  setNames(lapply(prompt_types, function(file) read.csv(paste0(path, file, ".csv"))), prompt_types)
}

# Function to calculate agreement matrix
create_agreement_matrix <- function(datasets) {
  expand.grid(Var1 = prompt_types, Var2 = prompt_types) %>%
    mutate(
      Var1 = factor(Var1, levels = prompt_types, labels = prompt_type_labels),
      Var2 = factor(Var2, levels = prompt_types, labels = prompt_type_labels),
      Agreement = mapply(function(df1, df2) mean(df1$headline.type == df2$headline.type, na.rm = TRUE) * 100,
                         datasets[Var1], datasets[Var2])
    )
}

# Function to plot agreement matrix
plot_agreement_matrix <- function(agreement_df, question, model, return_type, global_min, global_max) {
  ggplot(agreement_df, aes(x = Var1, y = Var2, fill = Agreement)) +
    geom_tile() +
    geom_text(aes(label = sprintf("%.1f", Agreement), color = ifelse(Agreement > 70, "white", "black")), size = 3, show.legend = FALSE) +
    scale_fill_viridis_c(option = "rocket", direction = -1, limits = c(global_min, global_max)) +
    scale_color_identity() +
    labs(
      title = glue("Pairwise Agreement by Prompting Strategy\n"),
      subtitle = glue("Question: {question_label_map[question]}\nModel: {model_label_map[model]}\nReturn Type: {return_label_map[return_type]}"),
      x = "Prompting Strategy", y = "Prompting Strategy", fill = "Pairwise Agreement Percent"
    ) +
    theme.heatmap
}

# Function to plot facet wrap agreement matrix
plot_agreement_matrix_all_returns <- function(facet_data, model, question) {
  ggplot(facet_data %>% filter(Model == model_label_map[model], Question == question_label_map[question]), 
         aes(x = Var1, y = Var2, fill = Agreement)) +
    geom_tile() +
    geom_text(aes(label = sprintf("%.1f", Agreement), color = ifelse(Agreement > 70, "white", "black")), size = 3, show.legend = FALSE) +
    scale_fill_viridis_c(option = "rocket", direction = -1, limits = c(global_min, global_max)) +
    scale_color_identity() +
    labs(
      title = glue("Pairwise Agreement by Prompting Strategy"),
      subtitle = glue("Model: {model_label_map[model]} | Question: {question_label_map[question]}"),
      x = "Prompting Strategy", y = "Prompting Strategy", fill = "Pairwise Agreement Percent"
    ) +
    theme.heatmap +
    facet_wrap(~ ReturnType, ncol = 3)
}

# Iterate over combinations and store data
all_datasets <- list()
agreement_matrices <- list()
global_min <- Inf
global_max <- -Inf

# Read data and calculate agreement matrices
for (return_type in return_types) {
  for (question in question_levels) {
    for (model in model_levels) {
      path <- glue("../data/step6_common_sample/within_model/{return_type}/{model}/{question}/")
      datasets <- read_datasets(path, prompt_types)
      
      # Store datasets for later use
      all_datasets[[paste0(return_type, " ", question, " ", model)]] <- datasets
      
      # Calculate and store agreement matrix
      agreement_df <- create_agreement_matrix(datasets)
      agreement_matrices[[paste0(return_type, " ", question, " ", model)]] <- agreement_df
      
      # Update global min and max
      global_min <- min(global_min, min(agreement_df$Agreement, na.rm = TRUE))
      global_max <- max(global_max, max(agreement_df$Agreement, na.rm = TRUE))
    }
  }
}

# Generate and save plots
lapply(names(agreement_matrices), function(name) {
  split_name <- strsplit(name, " ")[[1]]
  return_type <- split_name[1]
  question <- split_name[2]
  model <- split_name[3]
  
  plot <- plot_agreement_matrix(agreement_matrices[[name]], question, model, return_type, global_min, global_max)
  ggsave(filename = glue("../figures/heatmaps/by_return_type/{return_type}/{question}_{model}.png"), plot = plot, width = 7, height = 8, units = "in")
  print(glue("Saved heatmap for {model}, {question}, {return_type}"))
})


# Combine all agreement matrices into one data frame for facet wrapping
all_returns_matrices <- bind_rows(lapply(names(agreement_matrices), function(name) {
  split_name <- strsplit(name, " ")[[1]]
  return_type <- split_name[1]
  question <- split_name[2]
  model <- split_name[3]
  
  agreement_matrices[[name]] %>%
    mutate(
      Question = question_label_map[question],
      Model = model_label_map[model],
      ReturnType = return_label_map[return_type]
    )
}))


# Generate and save facet-wrap plots for each model and question combination
for (question in question_levels) {
  for (model in model_levels) {
    plot <- plot_agreement_matrix_all_returns(all_returns_matrices, model, question)
    ggsave(filename = glue("../figures/heatmaps/all_returns/{question}_{model}.png"), plot = plot, width = 12, height = 6, units = "in")
    print(glue("Saved heatmap for {model}, {question}"))
  }
}



