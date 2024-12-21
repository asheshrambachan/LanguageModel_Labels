# Load necessary libraries
library(dplyr)
library(stargazer)
library(glue)

# Read and preprocess data
load_and_preprocess <- function(filepath) {
  read.csv(filepath) %>%
    mutate(mag_v_conf = case_when(
      mag_v_conf == "no_interaction" ~ "No Interaction",
      mag_v_conf == "confidence" ~ "Confidence",
      mag_v_conf == "magnitude" ~ "Magnitude",
      TRUE ~ mag_v_conf
    )) %>%
    mutate(question = case_when(
     question == "q1" ~ "Question 1",
     question == "q2" ~ "Question 2",
     question == "q3" ~ "Question 3",
     question == "q4" ~ "Question 4",
     question == "q5" ~ "Question 5",
     TRUE ~ question
    ))
}

abnormal_CAPM <- load_and_preprocess("./data/step9_reg_results/abnormal_CAPM_returns_clustered.csv")
realized <- load_and_preprocess("./data/step9_reg_results/realized_returns_clustered.csv")
realized_fe <- load_and_preprocess("./data/step9_reg_results/realized_returns_fe.csv")

# Define a function to calculate summary statistics by group with renaming
calculate_summary <- function(data, coef_column) {
  data %>%
    group_by(question, mag_v_conf, ret) %>%
    summarize(
      Mean = mean({{ coef_column }}, na.rm = TRUE),
      Median = median({{ coef_column }}, na.rm = TRUE),
      `5th Percentile` = quantile({{ coef_column }}, 0.05, na.rm = TRUE),
      `95th Percentile` = quantile({{ coef_column }}, 0.95, na.rm = TRUE),
      `Average Return` = mean(return, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    rename(
      `Interaction Type` = mag_v_conf,
      `Return Horizon` = ret
    ) %>%
    mutate(across(where(is.numeric), ~ round(.x, 3)))
}

# Calculate summaries for "up" and "down" coefficients
abnormal_CAPM_summary <- list(
  up = calculate_summary(abnormal_CAPM, up.coef),
  down = calculate_summary(abnormal_CAPM, down.coef)
)
realized_summary <- list(
  up = calculate_summary(realized, up.coef),
  down = calculate_summary(realized, down.coef)
)

realized_fe_summary <- list(
  up = calculate_summary(realized_fe, up.coef),
  down = calculate_summary(realized_fe, down.coef)
)

# Filter data for specific return values
filter_return <- function(summary_data, ret_values) {
  summary_data %>% filter(`Return Horizon` %in% ret_values)
}

# Define function to create and save LaTeX tables
create_stargazer_table <- function(data, filename) {
  stargazer(data, type = "latex", summary = FALSE, out = filename, header = FALSE, digits = 3)
}

# Ensure directories exist
dir.create("./tables/all", recursive = TRUE, showWarnings = FALSE)

# Define a function to process and save tables
save_tables <- function(data, type, ret_values, label) {
  create_stargazer_table(filter_return(data, ret_values), 
                         glue::glue("./tables/all/{type}_{label}.tex"))
}

# Loop through summaries and save tables
ret_values <- list("1" = 1, "5_10" = c(5, 10))
for (name in names(abnormal_CAPM_summary)) {
  for (label in names(ret_values)) {
    save_tables(abnormal_CAPM_summary[[name]], paste0("abnormal_CAPM_", name), ret_values[[label]], label)
    save_tables(realized_summary[[name]], paste0("realized_", name), ret_values[[label]], label)
    save_tables(realized_fe_summary[[name]], paste0("realized_fe_", name), ret_values[[label]], label)
  }
}

# Nested loop through each question and mag_v_conf for additional tables
for (question_number in unique(abnormal_CAPM$question)) {
  for (mag_type in unique(abnormal_CAPM$mag_v_conf)) {
    dir.create(glue::glue("./tables/{question_number}"), showWarnings = FALSE)
    
    filter_and_save <- function(data, ret_values, type) {
      filtered <- data %>%
        filter(question == question_number, `Interaction Type` == mag_type, `Return Horizon` %in% ret_values)
      create_stargazer_table(filtered, glue::glue("./tables/{question_number}/{type}_{label}_{mag_type}.tex"))
    }
    
    for (label in names(ret_values)) {
      filter_and_save(abnormal_CAPM_summary$up, ret_values[[label]], "abnormal_CAPM_up")
      filter_and_save(abnormal_CAPM_summary$down, ret_values[[label]], "abnormal_CAPM_down")
      filter_and_save(realized_summary$up, ret_values[[label]], "realized_up")
      filter_and_save(realized_summary$down, ret_values[[label]], "realized_down")
      filter_and_save(realized_fe_summary$up, ret_values[[label]], "realized_fe_up")
      filter_and_save(realized_fe_summary$down, ret_values[[label]], "realized_fe_down")
    }
  }
}
