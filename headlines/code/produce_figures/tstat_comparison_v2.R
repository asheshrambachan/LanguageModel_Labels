# Load necessary libraries
library(tidyverse)
library(ggplot2)
library(glue)

# Reset environment
rm(list = ls())
source(file.path("./code/produce_figures/ggplot_theme.r"))

# Read in data and combine
abnormal_CAPM <- read.csv("./data/step9_reg_results/abnormal_CAPM_returns_clustered.csv")
realized <- read.csv("./data/step9_reg_results/realized_returns_clustered.csv")
realized_fe <- read.csv("./data/step9_reg_results/realized_returns_fe.csv")

ret_all <- rbind(abnormal_CAPM, realized, realized_fe) %>%
  rename(return_horizon = ret)

# Define factor levels and labels
model_levels <- c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o")
model_labels <- c("GPT-3.5", "GPT-4o-mini", "GPT-4o")
return_type_levels <- c("realized", "abnormal_CAPM", "realized_fe")
return_type_labels <- c("Realized Returns", "Abnormal Returns (CAPM)", "Realized Returns (Company and Date Fixed Effects)")

# Helper function to filter data by return horizon
filter_data_by_horizon <- function(plot_data, return_horizon_levels) {
  plot_data %>% filter(return_horizon %in% return_horizon_levels)
}

# Generalized helper function to arrange and apply ordering with flexible return horizons
prompt_index <- function(plot_data, model_name, coef_col, se_col, return_horizon_levels, return_horizon_labels) {
  
  # Filter data by the specified return horizons
  plot_data <- filter_data_by_horizon(plot_data, return_horizon_levels)
  
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
      # return_type = factor(return_type, levels = return_type_levels, labels = return_type_labels)
    )
}

# Generalized helper function to create prompt model indices
prompt_model_index <- function(plot_data, coef_col, se_col, return_horizon_levels, return_horizon_labels) {
  
  # Filter data by the specified return horizons
  plot_data <- filter_data_by_horizon(plot_data, return_horizon_levels)
  
  plot_data %>%
    filter(question == current_question) %>%
    mutate(tstat_value = !!sym(coef_col) / !!sym(se_col)) %>%
    group_by(return_horizon, mag_v_conf, return_type) %>%
    arrange(tstat_value) %>%
    mutate(index_id = row_number()) %>%
    ungroup() %>%
    mutate(
      model = factor(model, levels = model_levels, labels = model_labels),
      return_horizon = factor(return_horizon, levels = return_horizon_levels, labels = return_horizon_labels)
    )
}

# Helper function to compute global y-axis limits for magnitude and confidence plots, ensuring limits include at least -2 and 2
get_global_ylim_for_plots <- function(up_data, down_data, coef_col_up, se_col_up, coef_col_down, se_col_down, padding = 0.5) {
  # Magnitude plots (up and down)
  up_tstat_magnitude <- up_data %>%
    filter(mag_v_conf == "magnitude") %>%
    mutate(tstat_value = !!sym(coef_col_up) / !!sym(se_col_up)) %>%
    pull(tstat_value)
  
  down_tstat_magnitude <- down_data %>%
    filter(mag_v_conf == "magnitude") %>%
    mutate(tstat_value = !!sym(coef_col_down) / !!sym(se_col_down)) %>%
    pull(tstat_value)
  
  # Confidence plots (up and down)
  up_tstat_confidence <- up_data %>%
    filter(mag_v_conf == "confidence") %>%
    mutate(tstat_value = !!sym(coef_col_up) / !!sym(se_col_up)) %>%
    pull(tstat_value)
  
  down_tstat_confidence <- down_data %>%
    filter(mag_v_conf == "confidence") %>%
    mutate(tstat_value = !!sym(coef_col_down) / !!sym(se_col_down)) %>%
    pull(tstat_value)
  
  # No interaction plots (up and down)
  up_tstat_no_interaction <- up_data %>%
    filter(mag_v_conf == "no_interaction") %>%
    mutate(tstat_value = !!sym(coef_col_up) / !!sym(se_col_up)) %>%
    pull(tstat_value)
  
  down_tstat_no_interaction <- down_data %>%
    filter(mag_v_conf == "no_interaction") %>%
    mutate(tstat_value = !!sym(coef_col_down) / !!sym(se_col_down)) %>%
    pull(tstat_value)
  
  # Compute the global y-axis limits for magnitude and confidence
  ylim_magnitude <- c(min(c(up_tstat_magnitude, down_tstat_magnitude), na.rm = TRUE) - padding, 
                      max(c(up_tstat_magnitude, down_tstat_magnitude), na.rm = TRUE) + padding)
  
  ylim_confidence <- c(min(c(up_tstat_confidence, down_tstat_confidence), na.rm = TRUE) - padding, 
                       max(c(up_tstat_confidence, down_tstat_confidence), na.rm = TRUE) + padding)
  
  ylim_no_interaction <- c(min(c(up_tstat_no_interaction, down_tstat_no_interaction), na.rm = TRUE) - padding, 
                          max(c(up_tstat_no_interaction, down_tstat_no_interaction), na.rm = TRUE) + padding)
  
  # Ensure limits include at least -2 and 2
  ylim_magnitude <- c(min(ylim_magnitude[1], -2), max(ylim_magnitude[2], 2))
  ylim_confidence <- c(min(ylim_confidence[1], -2), max(ylim_confidence[2], 2))
  ylim_no_interaction <- c(min(ylim_no_interaction[1], -2), max(ylim_no_interaction[2], 2))
  
  return(list(ylim_magnitude = ylim_magnitude, ylim_confidence = ylim_confidence, ylim_no_interaction = ylim_no_interaction))
}

# Plotting function adjusted to facet by return horizon and up/down
create_comparison_plot <- function(data, metric_label, x_axis_label, alpha, ylim_range) {
  ggplot(data = data %>% filter(mag_v_conf == metric_label)) +
    geom_hline(yintercept = 0, color = my_palette[["black"]], linewidth = 0.2) + 
    geom_point(aes(x = index_id, y = tstat_value, color = model, shape = model, 
                   alpha = ifelse(model == "GPT-4o", 1, alpha)), size = 3) +
    facet_grid(rows = vars(return_horizon), cols = vars(up_down)) + 
    scale_color_manual(values = my_colors, name = NULL, breaks = names(my_shapes)) +
    scale_shape_manual(values = my_shapes, name = NULL, breaks = names(my_shapes)) + 
    scale_alpha_identity() + 
    labs(y = "t-scores", x = glue("{x_axis_label}")) + 
    theme.point +
    scale_y_continuous(limits = ylim_range, breaks = function(limits) {
      pretty_breaks <- scales::pretty_breaks()(limits)
      all_breaks <- unique(c(pretty_breaks, 1.96, -1.96))
      all_breaks <- all_breaks[!(all_breaks %in% c(2, -2))]
      all_breaks <- all_breaks[all_breaks >= limits[1] & all_breaks <= limits[2]]
      return(all_breaks)
    })
}


# Define a list of return horizon combinations
return_horizon_combinations <- list(
  list(levels = c(5, 10), labels = c("5-day", "10-day"), width = 8, suffix = "5_10_day"),
  list(levels = c(1), labels = c("1-day"), width = 4, suffix = "1_day")
)

# Iterate over return horizon combinations and questions to create plots
questions <- c("q1", "q2", "q3", "q4", "q5")
question_names <- c("Positive, Negative, or Neutral?", 
                    "Increase, Decrease, or Uncertain Change to Returns?",
                    "Increase, Decrease, or Uncertain Change to Returns at Time?",
                    "Increase, Decrease, or Uncertain Sentiment", 
                    "Increase, Decrease, or Uncertain Sentiment at Time")


for (ret_type in return_type_levels) {
  cat("processing return type: ", ret_type, "\n")
  for (comb in return_horizon_combinations) {
    return_horizon_levels <- comb$levels
    return_horizon_labels <- comb$labels
    fig_width <- comb$width
    fig_suffix <- comb$suffix
    
    for (i in seq_along(questions)) {
      
      cat("processing question: ", questions[i], "\n")
      current_question <- questions[i]
      x_axis_label <- paste("Question:", question_names[i])
  
      
      # Generate combined data using prompt_index
      combined_data <- bind_rows(
        prompt_index(ret_all, "gpt-4o", "up.coef", "up.se", return_horizon_levels, return_horizon_labels) %>%
          mutate(up_down = "up"),
        prompt_index(ret_all, "gpt-4o", "down.coef", "down.se", return_horizon_levels, return_horizon_labels) %>%
          mutate(up_down = "down")
        )  %>%
         filter(return_type == ret_type) %>%
         mutate(up_down = factor(up_down, levels = c("up", "down")))

      # Generate combined data using prompt_model_index
      combined_data_model <- bind_rows(
        prompt_model_index(ret_all, "up.coef", "up.se", return_horizon_levels, return_horizon_labels) %>%
          mutate(up_down = "up"),
        prompt_model_index(ret_all, "down.coef", "down.se", return_horizon_levels, return_horizon_labels) %>%
          mutate(up_down = "down")
      ) %>%
        filter(return_type == ret_type) %>%
        mutate(up_down = factor(up_down, levels = c("up", "down")))

      # Apply conditional labels based on the question type
      label_up <- if (current_question == "q1") "Positive" else "Increase"
      label_down <- if (current_question == "q1") "Negative" else "Decrease"

      # Apply labels after all transformations, filtering, and calculations
      combined_data <- combined_data %>%
        mutate(up_down = fct_recode(up_down, !!label_up := "up", !!label_down := "down"))

      combined_data_model <- combined_data_model %>%
        mutate(up_down = fct_recode(up_down, !!label_up := "up", !!label_down := "down"))

      # Compute global y-axis limits for the current subset
      ylim_ranges <- get_global_ylim_for_plots(
        combined_data %>% filter(up_down == label_up),
        combined_data %>% filter(up_down == label_down),
        "up.coef", "up.se", "down.coef", "down.se", padding = 0.5
      )

      # Define plot parameters for magnitude and confidence
      plot_params <- list(
        list(data = combined_data, metric_label = "magnitude", x_axis_label = glue("Prompt Index (Sorted)"), alpha = 0.7, ylim = ylim_ranges$ylim_magnitude),
        list(data = combined_data, metric_label = "confidence", x_axis_label = glue("Prompt Index (Sorted)"), alpha = 0.7, ylim = ylim_ranges$ylim_confidence),
        list(data = combined_data, metric_label = "no_interaction", x_axis_label = glue("Prompt Index (Sorted)"), alpha = 0.7, ylim = ylim_ranges$ylim_no_interaction)
      )

      plot_params_model <- list(
        list(data = combined_data_model, metric_label = "magnitude", x_axis_label = glue("Prompt-Model Index (Sorted)"), alpha = 0.7, ylim = ylim_ranges$ylim_magnitude),
        list(data = combined_data_model, metric_label = "confidence", x_axis_label = glue("Prompt-Model Index (Sorted)"), alpha = 0.7, ylim = ylim_ranges$ylim_confidence),
        list(data = combined_data_model, metric_label = "no_interaction", x_axis_label = glue("Prompt-Model Index (Sorted)"), alpha = 0.7, ylim = ylim_ranges$ylim_no_interaction)
      )

      # Generate and save plots for each metric using prompt_index
      prompt_index_plots <- lapply(plot_params, function(params) {
        plot <- create_comparison_plot(params$data, params$metric_label, params$x_axis_label, params$alpha, params$ylim)
        ggsave(filename = glue("./figures/t_stats/{questions[i]}_{ret_type}_{params$metric_label}_{fig_suffix}.png"), plot = plot, width = 11, height = fig_width)
      })

      # Generate and save plots for each metric using prompt_model_index
      prompt_model_index_plots <- lapply(plot_params_model, function(params) {
        plot <- create_comparison_plot(params$data, params$metric_label, params$x_axis_label, params$alpha, params$ylim)
        ggsave(filename = glue("./figures/t_stats/{questions[i]}_{ret_type}_model_{params$metric_label}_{fig_suffix}.png"), plot = plot, width = 11, height = fig_width)
      })
      
    }
  }
}
