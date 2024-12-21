library(tidyverse)
library(ggplot2)
library(stargazer)
library(fixest)
library(modelsummary)

# Reset environment 
rm(list = ls())
source(file.path("./code/produce_figures/ggplot_theme.r"))

# Function to mutate the data frame with new columns
mutate_data <- function(df, question) {
  if (question == "q1") {
    df %>%
      mutate(
        positive = ifelse(headline.type == "positive", 1, 0),
        negative = ifelse(headline.type == "negative", 1, 0),
        neutral = ifelse(headline.type == "neutral", 1, 0),
        across(c(positive, negative, neutral), list(confidence = ~ . * confidence, magnitude = ~ . * magnitude))
      )
  } else {
    df %>%
      mutate(
        increase = ifelse(headline.type == "increase", 1, 0),
        decrease = ifelse(headline.type == "decrease", 1, 0),
        uncertain = ifelse(headline.type == "uncertain", 1, 0),
        across(c(increase, decrease, uncertain), list(confidence = ~ . * confidence, magnitude = ~ . * magnitude))
      )
  }
}

# Function to run regressions and add results to list
run_regression <- function(df, outcome_var, variables) {
  formula <- as.formula(paste(outcome_var, "~", paste(variables, collapse = " + "), "- 1"))
  reg <- feols(formula, cluster = ~company_name + date, data = df)
  outcome_val <- mean(df[[outcome_var]], na.rm = TRUE)  # Calculating the mean as an example
  list(reg = reg, outcome_val = outcome_val)
}


# Main processing loop
file_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", "persona1", "persona2", "persona3", "persona4")
questions <- c("q1", "q2", "q3", "q4", "q5")
return_types <- c("abnormal_CAPM", "abnormal_FF3")
models <- c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o")
model_labels <- c("GPT-3.5", "GPT-4o-mini", "GPT-4o")
model_map <- setNames(model_labels, models)


# Iterate over both abnormal return types
for (return_type in return_types) {
  all_reg_list <- list() 
  meta_data <- data.frame()
  # Iterate over all questions and models
  for (q in questions) {
    for (m in models) {
      path <- glue::glue("./data/step6_common_sample/across_models/{return_type}/{m}/{q}/")
      data_list <- map(file_names, ~ read.csv(glue::glue("{path}{.x}.csv")) %>% mutate_data(question = q))
      
      outcome_vars <- c("sum_exret_1", "sum_exret_5", "sum_exret_10")
      predictor_types <- list(
        magnitude = if (q == "q1") {
          c("positive", "negative", "neutral", "positive_magnitude", "negative_magnitude", "neutral_magnitude")
        } else {
          c("increase", "decrease", "uncertain", "increase_magnitude", "decrease_magnitude", "uncertain_magnitude")
        },
        confidence = if (q == "q1") {
          c("positive", "negative", "neutral", "positive_confidence", "negative_confidence", "neutral_confidence")
        } else {
          c("increase", "decrease", "uncertain", "increase_confidence", "decrease_confidence", "uncertain_confidence")
        },
        no_interaction = if (q == "q1") {
          c("positive", "negative", "neutral")
        } else {
          c("increase", "decrease", "uncertain")
        }
      )
      
      # Loop over outcome variables (1-day, 5-day, 10-day)
      for (outcome_var in outcome_vars) {
        # Loop over predictor types ('magnitude' and 'confidence')
        for (pred_type in names(predictor_types)) {
          temp_reg_list <- list()  # Temporary list for the current predictor type
          
          # Loop over the datasets (different prompt strategies)
          for (i in seq_along(data_list)) {
            variables <- c(predictor_types[[pred_type]])
            regression_results <- run_regression(data_list[[i]], outcome_var, variables)
            reg <- regression_results$reg
            outcome_val <- regression_results$outcome_val
            
            temp_reg_list <- c(temp_reg_list, list(reg))
            
            # Collect metadata
            meta_data <- bind_rows(
              meta_data,
              data.frame(
                question = q, 
                model = m, 
                prompt = file_names[i], 
                mag_v_conf = pred_type, 
                outcome_val = outcome_val,
                ret = sub("sum_exret_", "", outcome_var)
              )
            )
          }
          
          # Add temp_reg_list to the master list
          all_reg_list <- c(all_reg_list, temp_reg_list)
          
          # Generate model summary for the current set of models
          coef_labels <- if (q == "q1") {
            if (pred_type == "magnitude") {
              c("Positive", "Negative", "Neutral", "Positive Magnitude", "Negative Magnitude", "Neutral Magnitude")
            } else if (pred_type == "confidence") {
              c("Positive", "Negative", "Neutral", "Positive Confidence", "Negative Confidence", "Neutral Confidence")
            } else {
              c("Positive", "Negative", "Neutral")
            }
          } else {
            if (pred_type == "magnitude") {
              c("Increase", "Decrease", "Uncertain", "Increase Magnitude", "Decrease Magnitude", "Uncertain Magnitude")
            } else if (pred_type == "confidence") {
              c("Increase", "Decrease", "Uncertain", "Increase Confidence", "Decrease Confidence", "Uncertain Confidence")
            } else {
              c("Increase", "Decrease", "Uncertain")
            }
          }
          
          print(modelsummary(
            temp_reg_list,
            coef_rename = coef_labels,
            gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE",
            stars = TRUE,
            output = "markdown"
          ))
        }
      }
      cat(m, q, "\n")
    }
  }
  # Create plot results
  plot_results <- map_dfr(seq_along(all_reg_list), function(i) {
    reg <- all_reg_list[[i]]
    coef_names <- if (meta_data$question[i] == "q1") c("positive", "negative") else c("increase", "decrease")
    
    data.frame(
      question = meta_data$question[i],
      return = meta_data$outcome_val[i],
      model = meta_data$model[i],
      prompt = meta_data$prompt[i],
      mag_v_conf = meta_data$mag_v_conf[i],
      ret = meta_data$ret[i],
      up.coef = reg$coefficients[coef_names[1]],
      down.coef = reg$coefficients[coef_names[2]],
      up.se = reg$se[coef_names[1]],
      down.se = reg$se[coef_names[2]],
      group_id = paste(meta_data$question[i], meta_data$mag_v_conf[i], meta_data$ret[i], meta_data$prompt[i], sep = "_")
    )
  })
  
  plot_results <- plot_results %>%
    group_by(group_id) %>%
    mutate(id = cur_group_id()) %>%
    ungroup()
  
  plot_results$return_type <- return_type
  write.csv(plot_results, glue::glue("./data/step9_reg_results/{return_type}_returns_clustered.csv"))
}