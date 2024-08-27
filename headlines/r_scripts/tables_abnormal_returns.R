library(dplyr)
library(ggplot2)
library(stargazer)
library(broom)
library(fixest)
library(modelsummary)

# reset workspace
rm(list = ls())

question = "q1"
return_type = "CAPM"
model = "gpt-4o-mini"

#-------------------------------------------------------------------------------
# helper functions
#-------------------------------------------------------------------------------

# Function to mutate the data frame with new columns
mutate_data <- function(df) {
  if (question == "q1") {
    df %>%
      mutate(
        positive = ifelse(headline.type == "positive", 1, 0),
        negative = ifelse(headline.type == "negative", 1, 0),
        neutral = ifelse(headline.type == "neutral", 1, 0),
        positive.confidence = positive * confidence,
        negative.confidence = negative * confidence,
        neutral.confidence = neutral * confidence,
        positive.magnitude = positive * magnitude,
        negative.magnitude = negative * magnitude,
        neutral.magnitude = neutral * magnitude,
      )
  }
  else {
    df %>%
      mutate(
        decrease = ifelse(headline.type == "decrease", 1, 0),
        increase = ifelse(headline.type == "increase", 1, 0),
        uncertain = ifelse(headline.type == "uncertain", 1, 0),
        decrease.confidence = decrease * confidence,
        increase.confidence = increase * confidence,
        uncertain.confidence = uncertain * confidence,
        decrease.magnitude = decrease * magnitude,
        increase.magnitude = increase * magnitude,
        uncertain.magnitude = uncertain * magnitude,
      )
  }
}

if (question != "q1") {
  magnitude_labels <- c("Increase", "Decrease", "Uncertain", "Increase Magnitude",
                        "Decrease Magnitude", "Uncertain Magnitude")
  confidence_labels <- c("Increase", "Decrease", "Uncertain", "Increase Confidence",
                         "Decrease Confidence", "Uncertain Confidence")
} else {
  magnitude_labels <- c("Positive", "Negative", "Neutral", "Positive Magnitude",
                        "Negative Magnitude", "Neutral Magnitude")
  confidence_labels <- c("Positive", "Negative", "Neutral", "Positive Confidence",
                         "Negative Confidence", "Neutral Confidence")
}

plot_regression_coefficients <- function(reg_list, file_names, title = "Regression Coefficients with Confidence Intervals") {
 
   # Placeholder list for storing coefficients and confidence intervals
  coef_list <- list()
  
  # Loop through the regression results and extract coefficients and confidence intervals
  for (i in 1:length(reg_list)) {
    coefs <- tidy(reg_list[[i]])
    coefs$Model <- file_names[i]
    coef_list[[i]] <- coefs
  }
  
  # Combine all coefficients into one data frame
  coef_df <- bind_rows(coef_list)
  
  # Calculate confidence intervals
  coef_df <- coef_df %>%
    mutate(
      lower = estimate - 1.96 * std.error,
      upper = estimate + 1.96 * std.error
    )
  
  # Plot the coefficients with confidence intervals
  ggplot(coef_df, aes(x = term, y = estimate, color = Model)) +
    geom_point(position = position_dodge(width = 0.5)) +
    geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.2, position = position_dodge(width = 0.5)) +
    facet_wrap(~ Model) +
    labs(title = title,
         x = "Headline Type",
         y = "Estimate") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

#-------------------------------------------------------------------------------
# read in data 
#-------------------------------------------------------------------------------
path = paste0("../data/step6_common_sample/", return_type, "/", model, "/", question, "/")

base_blanks <- read.csv(paste0(path, "base_blanks.csv"))
base_json <- read.csv(paste0(path, "base_json.csv"))
cot1 <- read.csv(paste0(path, "cot1.csv"))
cot2 <- read.csv(paste0(path, "cot2.csv"))
cot3 <- read.csv(paste0(path, "cot3.csv"))
persona1 <- read.csv(paste0(path, "persona1.csv"))
persona2 <- read.csv(paste0(path, "persona2.csv"))
persona3 <- read.csv(paste0(path, "persona3.csv"))
persona4 <- read.csv(paste0(path, "persona4.csv"))

data_list <- list(base_blanks, base_json, cot1, cot2, cot3, persona1, persona2, persona3, persona4)
data_list <- lapply(data_list, mutate_data)
file_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", "persona1", "persona2", "persona3", "persona4")

#-------------------------------------------------------------------------------
# returns 1 day post-headline (with magnitude)
#-------------------------------------------------------------------------------
# Placeholder lists for regression results
reg_list <- list()

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- feols(sum_exret_1 ~ increase +
                decrease +
                uncertain +
                increase.magnitude +
                decrease.magnitude +
                uncertain.magnitude - 1,
                cluster = ~company_name + date,
                data = data_list[[i]])

    reg_list[[i]] <- reg
  }
  else {
    reg <- feols(sum_exret_1 ~
                positive +
                negative +
                neutral +
                positive.magnitude +
                negative.magnitude +
                neutral.magnitude - 1,
                cluster = ~company_name + date,
                data = data_list[[i]])

    reg_list[[i]] <- reg
  }
}

modelsummary(reg_list,
             coef_rename = magnitude_labels,
             gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE",
             title = paste0(question, " Cumulative Abnormal Returns 1 Day Post-Headline (", return_type, ")\n Includes LLM-labeled Magnitude"),
             stars = TRUE)

plot_regression_coefficients(reg_list, file_names, paste0(question, " Cumulative Abnormal Returns 1 Day Post-Headline (", return_type, ")\n Includes LLM-labeled Magnitude"))
ggsave(filename = paste0("../temp_figs/coefficients/", model, "/", return_type, "_clustered_ses/", question, "/ret1_magnitude.jpeg"),
       units = "in", width = 8, height = 5)

#-------------------------------------------------------------------------------
#
# returns 5 day post-headline (with magnitude)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- feols(sum_exret_5 ~ increase +
                   decrease +
                   uncertain +
                   increase.magnitude +
                   decrease.magnitude +
                   uncertain.magnitude - 1,
                 cluster = ~company_name + date,
                 data = data_list[[i]])

    reg_list[[i]] <- reg
  }
  else {
    reg <- feols(sum_exret_5 ~
                   positive +
                   negative +
                   neutral +
                   positive.magnitude +
                   negative.magnitude +
                   neutral.magnitude - 1,
                 cluster = ~company_name + date,
                 data = data_list[[i]])

    reg_list[[i]] <- reg
  }
}

modelsummary(reg_list,
             coef_rename = magnitude_labels,
             gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE",
             # output = "latex",
             title =  paste0(question, " Cumulative Abnormal Returns 5 Days Post-Headline (", return_type, ")\n Includes LLM-labeled Magnitude"),
             stars = TRUE)

plot_regression_coefficients(reg_list, file_names, paste0(question, " Cumulative Abnormal Returns 5 Days Post-Headline (", return_type, ")\n Includes LLM-labeled Magnitude"))
ggsave(filename = paste0("../temp_figs/coefficients/", model, "/", return_type, "_clustered_ses/", question, "/ret5_magnitude.jpeg"),
       units = "in", width = 8, height = 5)

#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (with magnitude)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- feols(sum_exret_10 ~ increase +
                   decrease +
                   uncertain +
                   increase.magnitude +
                   decrease.magnitude +
                   uncertain.magnitude - 1,
                 cluster = ~company_name + date,
                 data = data_list[[i]])

    reg_list[[i]] <- reg
  }
  else {
    reg <- feols(sum_exret_10 ~
                   positive +
                   negative +
                   neutral +
                   positive.magnitude +
                   negative.magnitude +
                   neutral.magnitude - 1,
                 cluster = ~company_name + date,
                 data = data_list[[i]])

    reg_list[[i]] <- reg
  }
}

modelsummary(reg_list,
             coef_rename = magnitude_labels,
             gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE",
             # output = "latex",
             title = paste0(question, " Cumulative Abnormal Returns 10 Days Post-Headline (", return_type, ")\n Includes LLM-labeled Magnitude"),
             stars = TRUE)

plot_regression_coefficients(reg_list, file_names, paste0(question, " Cumulative Abnormal Returns 10 Days Post-Headline (", return_type, ")\n Includes LLM-labeled Magnitude"))
ggsave(filename = paste0("../temp_figs/coefficients/", model, "/", return_type, "_clustered_ses/", question, "/ret10_magnitude.jpeg"),
       units = "in", width = 8, height = 5)

# #-------------------------------------------------------------------------------
# #
# # returns 1 day post-headline (with confidence)
# #
# #-------------------------------------------------------------------------------
# reg_list <- list()
# 
# # Run regressions in a loop
# for (i in 1:length(data_list)) {
#   if (question != "q1") {
#     reg <- feols(sum_exret_1 ~ increase + 
#                    decrease +
#                    uncertain +
#                    increase.confidence +
#                    decrease.confidence +
#                    uncertain.confidence - 1,
#                  cluster = ~company_name + date,
#                  data = data_list[[i]])
#     
#     reg_list[[i]] <- reg
#   }
#   else {
#     reg <- feols(sum_exret_1 ~ 
#                    positive + 
#                    negative +
#                    neutral +
#                    positive.confidence +
#                    negative.confidence +
#                    neutral.confidence - 1,
#                  cluster = ~company_name + date,
#                  data = data_list[[i]])
#     
#     reg_list[[i]] <- reg
#   }
# }
# 
# modelsummary(reg_list, 
#              coef_rename = confidence_labels,
#              gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE", 
#              # output = "latex",
#              title = paste0(question, " Cumulative Abnormal Returns 1 Day Post-Headline (", return_type, ")\n Includes LLM-labeled Confidence"),
#              stars = TRUE)
# 
# plot_regression_coefficients(reg_list, file_names, paste0(question, " Cumulative Abnormal Returns 1 Day Post-Headline (", return_type, ")\n Includes LLM-labeled Confidence"))
# ggsave(filename = paste0("../temp_figs/coefficients/", model, "/", return_type, "_clustered_ses/", question, "/ret1_confidence.jpeg"),
#        units = "in", width = 8, height = 5)
# 
# #-------------------------------------------------------------------------------
# #
# # returns 5 day post-headline (with confidence)
# #
# #-------------------------------------------------------------------------------
# # Placeholder lists for regression results and standard errors
# 
# reg_list <- list()
# 
# # Run regressions in a loop
# for (i in 1:length(data_list)) {
#   if (question != "q1") {
#     reg <- feols(sum_exret_5 ~ increase + 
#                    decrease +
#                    uncertain +
#                    increase.confidence +
#                    decrease.confidence +
#                    uncertain.confidence - 1,
#                  cluster = ~company_name + date,
#                  data = data_list[[i]])
#     
#     reg_list[[i]] <- reg
#   }
#   else {
#     reg <- feols(sum_exret_5 ~ 
#                    positive + 
#                    negative +
#                    neutral +
#                    positive.confidence +
#                    negative.confidence +
#                    neutral.confidence - 1,
#                  cluster = ~company_name + date,
#                  data = data_list[[i]])
#     
#     reg_list[[i]] <- reg
#   }
# }
# 
# modelsummary(reg_list, 
#              coef_rename = confidence_labels,
#              gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE",  
#              # output = "latex",
#              title = paste0(question, " Cumulative Abnormal Returns 5 Days Post-Headline (", return_type, ")\n Includes LLM-labeled Confidence"),
#              stars = TRUE)
# 
# plot_regression_coefficients(reg_list, file_names, paste0(question, " Cumulative Abnormal Returns 5 Days Post-Headline (", return_type, ")\n Includes LLM-labeled Confidence"))
# ggsave(filename = paste0("../temp_figs/coefficients/", model, "/", return_type, "_clustered_ses/", question, "/ret5_confidence.jpeg"),
#        units = "in", width = 8, height = 5)
# 
# #-------------------------------------------------------------------------------
# #
# # returns 10 day post-headline (with confidence)
# #
# #-------------------------------------------------------------------------------
# # Placeholder lists for regression results and standard errors
# reg_list <- list()
# 
# # Run regressions in a loop
# for (i in 1:length(data_list)) {
#   if (question != "q1") {
#     reg <- feols(sum_exret_10 ~ increase + 
#                    decrease +
#                    uncertain +
#                    increase.confidence +
#                    decrease.confidence +
#                    uncertain.confidence - 1,
#                  cluster = ~company_name + date,
#                  data = data_list[[i]])
#     
#     reg_list[[i]] <- reg
#   }
#   else {
#     reg <- feols(sum_exret_10 ~ 
#                    positive + 
#                    negative +
#                    neutral +
#                    positive.confidence +
#                    negative.confidence +
#                    neutral.confidence - 1,
#                  cluster = ~company_name + date,
#                  data = data_list[[i]])
#     
#     reg_list[[i]] <- reg
#   }
# }
# 
# modelsummary(reg_list, 
#              coef_rename = confidence_labels,
#              gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE", 
#              # output = "latex",
#              title = paste0(question, " Cumulative Abnormal Returns 10 Days Post-Headline (", return_type, ")\n Includes LLM-labeled Confidence"),
#              stars = TRUE)
# 
# plot_regression_coefficients(reg_list, file_names, paste0(question, " Cumulative Abnormal Returns 10 Days Post-Headline (", return_type, ")\n Includes LLM-labeled Confidence"))
# ggsave(filename = paste0("../temp_figs/coefficients/", model, "/", return_type, "_clustered_ses/", question, "/ret10_confidence.jpeg"),
#        units = "in", width = 8, height = 5)
