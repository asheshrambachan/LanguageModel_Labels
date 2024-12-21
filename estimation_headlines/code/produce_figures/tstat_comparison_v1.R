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

ret_all <- rbind(abnormal_CAPM, realized) %>%
  rename(return_horizon = ret)

# Define factor levels and labels
model_levels <- c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o")
model_labels <- c("GPT-3.5", "GPT-4o-mini", "GPT-4o")
return_type_levels <- c("realized", "abnormal_CAPM")
return_type_labels <- c("Realized Returns", "Abnormal Returns (CAPM)")


# Helper function to filter data by return horizon
filter_data_by_horizon <- function(plot_data, return_horizon_levels) {
  plot_data %>% filter(return_horizon %in% return_horizon_levels)
}

# Generalized helper function to arrange and apply ordering with flexible return horizons
prompt_index_general <- function(plot_data, model_name, coef_col, se_col, return_horizon_levels, return_horizon_labels) {
  
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
      return_type = factor(return_type, levels = return_type_levels, labels = return_type_labels)
    )
}

# Generalized helper function to create prompt model indices
prompt_model_index_general <- function(plot_data, coef_col, se_col, return_horizon_levels, return_horizon_labels) {
  
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
      return_type = factor(return_type, levels = return_type_levels, labels = return_type_labels),
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
  
  # Compute the global y-axis limits for magnitude and confidence
  ylim_magnitude <- c(min(c(up_tstat_magnitude, down_tstat_magnitude), na.rm = TRUE) - padding, 
                      max(c(up_tstat_magnitude, down_tstat_magnitude), na.rm = TRUE) + padding)
  
  ylim_confidence <- c(min(c(up_tstat_confidence, down_tstat_confidence), na.rm = TRUE) - padding, 
                       max(c(up_tstat_confidence, down_tstat_confidence), na.rm = TRUE) + padding)
  
  # Ensure limits include at least -2 and 2
  ylim_magnitude <- c(min(ylim_magnitude[1], -2), max(ylim_magnitude[2], 2))
  ylim_confidence <- c(min(ylim_confidence[1], -2), max(ylim_confidence[2], 2))
  
  return(list(ylim_magnitude = ylim_magnitude, ylim_confidence = ylim_confidence))
}


create_comparison_plot <- function(data, metric_label, x_axis_label, alpha, ylim_range) {
  ggplot(data = data %>% filter(mag_v_conf == metric_label)) +
    geom_hline(yintercept = 0, color = my_palette[["black"]], linewidth = 0.2) + 
    geom_point(aes(x = index_id, y = tstat_value, color = model, shape = model, 
                   alpha = ifelse(model == "GPT-4o", 1, alpha)), size = 3) +
    facet_grid(rows = vars(return_type), cols = vars(return_horizon)) + 
    scale_color_manual(values = my_colors, name = NULL, breaks = names(my_shapes)) +
    scale_shape_manual(values = my_shapes, name = NULL, breaks = names(my_shapes)) + 
    scale_alpha_identity() + 
    labs(y = "t-scores", x = x_axis_label) + 
    theme.point +

    scale_y_continuous(limits = ylim_range, breaks = function(limits) {
      # Generate a sequence of breaks
      pretty_breaks <- scales::pretty_breaks()(limits)
      # Add 1.96 and -1.96 to the breaks
      all_breaks <- unique(c(pretty_breaks, 1.96, -1.96))
      # Check if 2 and -2 are in all_breaks, and remove them if they are
      all_breaks <- all_breaks[!(all_breaks %in% c(2, -2))]
      # Ensure the breaks are sorted and within limits
      all_breaks <- all_breaks[all_breaks >= limits[1] & all_breaks <= limits[2]]
      return(all_breaks)
    })
}



# Define a list of return horizon combinations
return_horizon_combinations <- list(
  # list(levels = c(5, 10), labels = c("5-day", "10-day"), width = 11, suffix = "5_10_day"),
  list(levels = c(1), labels = c("1-day"), width = 5.5, suffix = "1_day")
)

# Iterate over return horizon combinations and questions to create plots
questions <- c("q4")
question_names <- c("Increase, Decrease, or Uncertain Sentiment")

# Create plots with adjusted ylim to ensure visibility of the 1.96 +/- lines
for (comb in return_horizon_combinations) {
  return_horizon_levels <- comb$levels
  return_horizon_labels <- comb$labels
  fig_width <- comb$width
  fig_suffix <- comb$suffix
  
  for (i in seq_along(questions)) {
    current_question <- questions[i]
    x_axis_label <- paste("Question:", question_names[i])
    
    # Create and apply order for 'up' and 'down' with current return horizons
    up_index <- prompt_index_general(ret_all, "gpt-4o", "up.coef", "up.se", return_horizon_levels, return_horizon_labels)
    down_index <- prompt_index_general(ret_all, "gpt-4o", "down.coef", "down.se", return_horizon_levels, return_horizon_labels)
    
    # Compute global y-axis limits across magnitude and confidence for 'up' and 'down'
    ylim_ranges <- get_global_ylim_for_plots(up_index, down_index, "up.coef", "up.se", "down.coef", "down.se", padding = 0.5)
    
    # Create plots using lapply for 'up' and 'down', 'magnitude' and 'confidence' with consistent ylim
    plot_params <- list(
      list(data = up_index, metric_label = "magnitude", x_axis_label = glue("Prompt Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "up", ylim = ylim_ranges$ylim_magnitude),
      list(data = down_index, metric_label = "magnitude", x_axis_label = glue("Prompt Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "down", ylim = ylim_ranges$ylim_magnitude),
      list(data = up_index, metric_label = "confidence", x_axis_label = glue("Prompt Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "up", ylim = ylim_ranges$ylim_confidence),
      list(data = down_index, metric_label = "confidence", x_axis_label = glue("Prompt Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "down", ylim = ylim_ranges$ylim_confidence)
    )
    
    prompt_index_plots <- lapply(plot_params, function(params) {
      plot <- create_comparison_plot(params$data, params$metric_label, params$x_axis_label, params$alpha, params$ylim)
      ggsave(filename = glue("./figures/t_stats/slides/{questions[i]}_prompt_{params$direction}_{params$metric_label}_{fig_suffix}.png"), plot = plot, width = fig_width, height = 4)
    })
    
    # Create prompt model indices with current return horizons
    up_prompt_model_index <- prompt_model_index_general(ret_all, "up.coef", "up.se", return_horizon_levels, return_horizon_labels)
    down_prompt_model_index <- prompt_model_index_general(ret_all, "down.coef", "down.se", return_horizon_levels, return_horizon_labels)
    
    # Create plots for model indices using lapply with consistent ylim
    prompt_model_index_params <- list(
      list(data = up_prompt_model_index, metric_label = "magnitude", x_axis_label = glue("Prompt-Model Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "up", ylim = ylim_ranges$ylim_magnitude),
      list(data = down_prompt_model_index, metric_label = "magnitude", x_axis_label = glue("Prompt-Model Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "down", ylim = ylim_ranges$ylim_magnitude),
      list(data = up_prompt_model_index, metric_label = "confidence", x_axis_label = glue("Prompt-Model Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "up", ylim = ylim_ranges$ylim_confidence),
      list(data = down_prompt_model_index, metric_label = "confidence", x_axis_label = glue("Prompt-Model Index (Sorted)\n {x_axis_label}"), alpha = 0.7, direction = "down", ylim = ylim_ranges$ylim_confidence)
    )
    
    prompt_model_index_plots <- lapply(prompt_model_index_params, function(params) {
      plot <- create_comparison_plot(params$data, params$metric_label, params$x_axis_label, params$alpha, params$ylim)
      ggsave(filename = glue("./figures/t_stats/slides/{questions[i]}_prompt_model_{params$direction}_{params$metric_label}_{fig_suffix}.png"), plot = plot, width = fig_width, height = 4)
    })
  }
}
