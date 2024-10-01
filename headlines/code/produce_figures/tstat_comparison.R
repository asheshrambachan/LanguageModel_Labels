library(tidyverse)
library(ggplot2)
library(glue)

# Reset environment
rm(list = ls())
source(file.path("./code/produce_figures/ggplot_theme.r"))

# Read in data and combine
abnormal_CAPM <- read.csv("./data/step9_reg_results/abnormal_CAPM_returns_clustered.csv")
abnormal_FF3 <- read.csv("./data/step9_reg_results/abnormal_FF3_returns_clustered.csv")
realized <- read.csv("./data/step9_reg_results/realized_returns_clustered.csv")

ret_all <- rbind(abnormal_CAPM, abnormal_FF3, realized) %>%
  rename(return_horizon = ret)

# Define factor levels and labels
model_levels <- c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o")
model_labels <- c("GPT-3.5", "GPT-4o-mini", "GPT-4o")
return_type_levels <- c("realized", "abnormal_CAPM", "abnormal_FF3")
return_type_labels <- c("Realized Returns", "Abnormal Returns (CAPM)", "Abnormal Returns (FF3)")
return_horizon_levels <- c(1,5,10)
return_horizon_labels <- c("1-day", "5-day", "10-day")

# Helper function to arrange and apply ordering
prompt_index <- function(plot_data, model_name, coef_col, se_col) {
  
  # Arrange the data for the specified model
  ordered_data <- plot_data %>%
    filter(model == model_name, question == current_question) %>%
    group_by(return_horizon, return_type, mag_v_conf) %>%
    mutate(tstat_value = !!sym(coef_col) / !!sym(se_col)) %>%
    arrange(tstat_value) %>%
    mutate(new_id = row_number()) %>%
    ungroup()
  
  # Apply the ordering to the entire dataset
  plot_data %>%
    filter(question == current_question) %>%
    mutate(tstat_value = !!sym(coef_col) / !!sym(se_col)) %>%
    left_join(ordered_data %>% select(group_id, return_horizon, return_type, mag_v_conf, new_id), 
              by = c("group_id", "return_horizon", "return_type", "mag_v_conf")) %>%
    select(-any_of("id")) %>%
    rename(index_id = new_id) %>%
    mutate(
      model = factor(model, levels = model_levels, labels = model_labels),
      return_horizon = factor(return_horizon, levels = return_horizon_levels, labels = return_horizon_labels),
      return_type = factor(return_type, levels = return_type_levels, labels = return_type_labels)
    )
}

prompt_model_index <- function(plot_data, coef_col, se_col) {
  plot_data %>%
    filter(question == current_question) %>%
    mutate(tstat_value = !!sym(coef_col) / !!sym(se_col)) %>%
    group_by(return_horizon, mag_v_conf, return_type) %>%
    arrange(tstat_value) %>%
    mutate(index_id = row_number()) %>%
    ungroup() %>%
    mutate(
      model = factor(model, levels = model_levels, labels = model_labels),
      return_type = factor(return_type, levels = return_type_levels),
      return_horizon = factor(return_horizon, levels = return_horizon_levels, labels = return_horizon_labels)
    )
}

# Helper function to create plots with different shapes for each model
create_comparison_plot <- function(data, metric_label, x_axis_label, alpha) {
  ggplot(data = data %>% filter(mag_v_conf == metric_label)) +
    geom_hline(yintercept = 0, color = my_palette[["black"]], linewidth = 0.2) + # x-axis
    geom_point(aes(x = index_id, y = tstat_value, color = model, shape = model, 
                   alpha = ifelse(model == "GPT-4o", 1, alpha)), size = 3) +
    facet_grid(rows = vars(return_type), cols = vars(return_horizon)) + 
    scale_color_manual(values = my_colors, name = NULL, breaks = names(my_shapes)) +
    scale_shape_manual(values = my_shapes, name = NULL, breaks = names(my_shapes)) + 
    scale_alpha_identity() + 
    labs(y = "t-scores", x = x_axis_label) + 
    theme.point
}

# Iterate over questions and create plots
questions <- c("q1", "q2", "q3", "q4", "q5")
question_names <- c("Positive, Negative, or Neutral?", 
                    "Increase, Decrease, or Uncertain Change to Returns?",
                    "Increase, Decrease, or Uncertain Change to Returns at Time?",
                    "Increase, Decrease, or Uncertain Sentiment", 
                    "Increase, Decrease, or Uncertain Sentiment at Time")

for (i in seq_along(questions)) {
  current_question <- questions[i]
  x_axis_label <- paste("Question:", question_names[i])
  
  # Create and apply order for 'up' and 'down'
  up_index <- prompt_index(ret_all, "gpt-4o", "up.coef", "up.se")
  down_index <- prompt_index(ret_all, "gpt-4o", "down.coef", "down.se")
  
  # Create plots using lapply for 'up' and 'down', 'magnitude' and 'confidence'
  plot_params <- list(
    list(data = up_index, metric_label = "magnitude", x_axis_label = glue("Prompt Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "up"),
    list(data = up_index, metric_label = "confidence", x_axis_label = glue("Prompt Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "up"),
    list(data = down_index, metric_label = "magnitude", x_axis_label = glue("Prompt Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "down"),
    list(data = down_index, metric_label = "confidence", x_axis_label = glue("Prompt Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "down")
  )
  
  prompt_index_plots <- lapply(plot_params, function(params) {
    plot <- create_comparison_plot(params$data, params$metric_label, params$x_axis_label, params$alpha)
    ggsave(filename = glue("./figures/t_stats/{questions[i]}_prompt_{params$direction}_{params$metric_label}.png"), plot = plot, width = 10, height = 7)
  })
  
  # Create prompt model indices
  up_prompt_model_index <- prompt_model_index(ret_all, "up.coef", "up.se")
  down_prompt_model_index <- prompt_model_index(ret_all, "down.coef", "down.se")
  
  # Create plots for model indices using lapply
  prompt_model_index_params <- list(
    list(data = up_prompt_model_index, metric_label = "magnitude", x_axis_label = glue("Prompt-Model Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "up"),
    list(data = up_prompt_model_index, metric_label = "confidence", x_axis_label = glue("Prompt-Model Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "up"),
    list(data = down_prompt_model_index, metric_label = "magnitude", x_axis_label = glue("Prompt-Model Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "down"),
    list(data = down_prompt_model_index, metric_label = "confidence", x_axis_label = glue("Prompt-Model Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "down")
  )
  
  prompt_model_index_plots <- lapply(prompt_model_index_params, function(params) {
    plot <- create_comparison_plot(params$data, params$metric_label, params$x_axis_label, params$alpha)
    ggsave(filename = glue("./figures/t_stats/{questions[i]}_prompt_model_{params$direction}_{params$metric_label}.png"), plot = plot, width = 10, height = 7)
  })
}
