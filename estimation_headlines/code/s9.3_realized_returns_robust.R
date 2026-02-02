library(dplyr)
library(ggplot2)
library(stargazer)
library(lmtest)
library(sandwich)
library(glue)
library(purrr)

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
  reg <- lm(formula, data = df)
  se <- vcovHC(reg, type = "HC1")
  reg <- coeftest(reg, vcov = se)
  return(reg)
}

# Main processing loop
file_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", "persona1", "persona2", "persona3", "persona4")
# questions <- c("q1", "q2", "q3", "q4", "q5")
questions <- c("q1", "q2", "q4")

return_type <- "realized"
models <- c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o", "gpt-5-mini", "gpt-5-nano")
model_labels <- c("GPT-3.5", "GPT-4o-mini", "GPT-4o", "GPT-5-mini", "GPT-5-nano")
model_map <- setNames(model_labels, models)

meta_data <- data.frame()
all_reg_list <- list()  # Master list to store all regression results

# Iterate over all questions and models
for (q in questions) {
  for (m in models) {
    path <- glue::glue("./data/step6_common_sample/across_models/{return_type}/{m}/{q}/")
    data_list <- map(file_names, ~ read.csv(glue::glue("{path}{.x}.csv")) %>% mutate_data(question = q))
    
    outcome_vars <- c("ret_fd1", "ret_fd5", "ret_fd10")
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
      }
    )
    
    # Loop over outcome variables (1-day, 5-day, 10-day)
    for (outcome_var in outcome_vars) {
      # Loop over predictor types ('magnitude' and 'confidence')
      for (pred_type in names(predictor_types)) {
        temp_reg_list <- list()  # Temporary list for the current predictor type
        
        # Loop over the datasets (different prompt strategies)
        for (i in seq_along(data_list)) {
          variables <- c(predictor_types[[pred_type]], "ret_ld1", "ret_ld2", "ret_ld3")
          reg <- run_regression(data_list[[i]], outcome_var, variables)
          temp_reg_list <- c(temp_reg_list, list(reg))
          
          # Collect metadata
          meta_data <- bind_rows(
            meta_data,
            data.frame(
              question = q, 
              model = m, 
              prompt = file_names[i], 
              mag_v_conf = pred_type, 
              ret = sub("ret_fd", "", outcome_var)
            )
          )
        }
        
        # Add temp_reg_list to the master list
        all_reg_list <- c(all_reg_list, temp_reg_list)
        
        # Generate model summary for the current set of models
        coef_labels <- if (q == "q1") {
          if (pred_type == "magnitude") {
            c("Positive", "Negative", "Neutral", "Positive Magnitude", "Negative Magnitude", "Neutral Magnitude", "Ret LD1", "Ret LD2", "Ret LD3")
          } else {
            c("Positive", "Negative", "Neutral", "Positive Confidence", "Negative Confidence", "Neutral Confidence", "Ret LD1", "Ret LD2", "Ret LD3")
          }
        } else {
          if (pred_type == "magnitude") {
            c("Increase", "Decrease", "Uncertain", "Increase Magnitude", "Decrease Magnitude", "Uncertain Magnitude", "Ret LD1", "Ret LD2", "Ret LD3")
          } else {
            c("Increase", "Decrease", "Uncertain", "Increase Confidence", "Decrease Confidence", "Uncertain Confidence", "Ret LD1", "Ret LD2", "Ret LD3")
          }
        }
        
        # stargazer(temp_reg_list, type = "text", se = se_list, 
        #           title = "10 Day Post Headline Returns Regressed on Headline Type (with Confidence)",
        #           covariate.labels = confidence_labels,
        #           dep.var.labels = "Realized Return 10 Day-Post Headline",
        #           model.names = TRUE,
        #           notes = obs_note)
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
    model = meta_data$model[i],
    prompt = meta_data$prompt[i],
    mag_v_conf = meta_data$mag_v_conf[i],
    ret = meta_data$ret[i],
    up.coef = reg[coef_names[1], "Estimate"],
    down.coef = reg[coef_names[2], "Estimate"],
    up.se = reg[coef_names[1], "Std. Error"],
    down.se = reg[coef_names[2], "Std. Error"],
    group_id = paste(meta_data$question[i], meta_data$mag_v_conf[i], meta_data$ret[i], meta_data$prompt[i], sep = "_")
  )
})

plot_results <- plot_results %>%
  group_by(group_id) %>%
  mutate(id = cur_group_id()) %>%
  ungroup()

plot_results$return_type <- return_type
write.csv(plot_results, glue("./data/step9_reg_results/{return_type}_returns_robust.csv"))
