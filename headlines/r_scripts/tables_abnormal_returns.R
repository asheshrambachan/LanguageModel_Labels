library(dplyr)
library(ggplot2)
library(stargazer)
library(broom)
library(fixest)
library(modelsummary)

rm(list = ls())

# Define the question and the list of months
question <- "q1"
months <- c("jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "octfirst", "octsecond", "nov", "dec")
year = "19"
return_type = "CAPM"
model = "gpt-4o-mini"

# Function to read and combine data for all months
read_and_combine <- function(file_name, months, question) {
  combined_df <- data.frame()  # Initialize an empty data frame to store combined data
  for (month in months) {
    file_path <- paste0("./data/step5_returns_merged/", 
                        return_type, "/", 
                        model, "/", 
                        question, "/",  
                        question, "_", month, "19/", 
                        file_name)
    month_df <- read.csv(file_path)
    month_df <- subset(month_df, headline.type != "")  # Filter out rows with empty headline.type
    combined_df <- bind_rows(combined_df, month_df)  # Combine data frames
  }
  return(combined_df)
}

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

# List of file names
file_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", 
                "persona1", "persona2", "persona3", "persona4")

# Step 1: Read, combine, and mutate data for all files
combined_data <- lapply(file_names, function(file_name) {
  df <- read_and_combine(paste0(file_name, ".csv"), months, question)
  df <- mutate_data(df)
  df$headline  # Return only the headlines column
})

# Step 2: Find the intersection of headlines across all datasets
common_headlines <- Reduce(intersect, combined_data)

# Step 3: Re-read, combine, mutate, and filter each dataset based on common headlines
filtered_data <- lapply(file_names, function(file_name) {
  df <- read_and_combine(paste0(file_name, ".csv"), months, question)
  df <- mutate_data(df)
  df <- df %>% 
    filter(headline %in% common_headlines) %>%
    filter(!is.na(sum_exret_1) & !is.na(sum_exret_5) & !is.na(sum_exret_10))
  return(df)
})

# Assign the filtered and mutated data to respective variables
base_blanks <- filtered_data[[1]]
base_json <- filtered_data[[2]]
cot1 <- filtered_data[[3]]
cot2 <- filtered_data[[4]]
cot3 <- filtered_data[[5]]
persona1 <- filtered_data[[6]]
persona2 <- filtered_data[[7]]
persona3 <- filtered_data[[8]]
persona4 <- filtered_data[[9]]

rm(filtered_data)


# List of datasets
data_list <- list(base_blanks, base_json, persona1, persona2, persona3, persona4, cot1, cot2, cot3)

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
#
# returns 1 day post-headline (with magnitude)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
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
             stars = TRUE)

plot_regression_coefficients(reg_list, file_names, paste0("1-day CAR Regression Coefficients with Confidence Intervals (", return_type, ")"))
ggsave(filename = paste0("temp_figs/coefficients/", model, "/", return_type, "_robust_ses/", question, "/ret1_magnitude.jpeg"),
       units = "in", width = 8, height = 5)

#-------------------------------------------------------------------------------
#
# returns 5 day post-headline (with magnitude)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()
se_list <- list()
n_list <- list()

outcome = ifelse(return_type == "CAPM", "CAPM_CAR_5", "FF3_CAR_5")

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- lm(data_list[[i]][[outcome]] ~ increase + 
                decrease +
                uncertain +
                increase.magnitude +
                decrease.magnitude +
                uncertain.magnitude - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  }
  else {
    reg <- lm(data_list[[i]][[outcome]] ~ 
                positive + 
                negative +
                neutral +
                positive.magnitude +
                negative.magnitude +
                neutral.magnitude - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  }
}

# Create custom note with the number of observations
obs_note <- paste("Observations: ", paste(n_list[1:9], collapse = ", "))

# Create stargazer tables
stargazer(reg_list[1:9], type = "latex", se = se_list[1:9], 
          title = paste0(model, " ", question, ": ", "5 Day Post Headline Returns Regressed on Headline Type (with Magnitude)"),
          covariate.labels = magnitude_labels,
          dep.var.labels = "CAR FD5",
          model.names = TRUE,
          notes = obs_note)

plot_regression_coefficients(reg_list, file_names, paste0("5-day CAR Regression Coefficients with Confidence Intervals (", return_type, ")"))
ggsave(filename = paste0("temp_figs/coefficients/", model, "/", return_type, "_robust_ses/", question, "/ret5_magnitude.jpeg"),
       units = "in", width = 8, height = 5)

# ## TEMP BEIGN
# reg_list[1:9] %>%
#   purrr::map(function(x) matrix(as.double(x), ncol = ncol(x), dimnames = dimnames(x))) %>%
#   purrr::map(t) %>%
#   purrr::map(as_tibble, rownames = "name")
#   purrr::map(class)
# 
# ## TEMP END


#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (with magnitude)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()
se_list <- list()
n_list <- list()

outcome = ifelse(return_type == "CAPM", "CAPM_CAR_10", "FF3_CAR_10")

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- lm(data_list[[i]][[outcome]] ~ 
                increase + 
                decrease +
                uncertain +
                increase.magnitude +
                decrease.magnitude +
                uncertain.magnitude - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  } else {
    reg <- lm(data_list[[i]][[outcome]] ~ 
                positive + 
                negative +
                neutral +
                positive.magnitude +
                negative.magnitude +
                neutral.magnitude - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  }
}

# Create custom note with the number of observations
obs_note <- paste("Observations: ", paste(n_list[1:9], collapse = ", "))

# Create stargazer tables
stargazer(reg_list[1:9], type = "latex", se = se_list[1:9], 
          title = paste0(model, " ", question, ": ", "10 Day Post Headline Returns Regressed on Headline Type (with Magnitude)"),
          covariate.labels = magnitude_labels,
          dep.var.labels = "CAR FD10",
          model.names = TRUE,
          notes = obs_note)

plot_regression_coefficients(reg_list, file_names, paste0("10-day CAR Regression Coefficients with Confidence Intervals (", return_type, ")"))
ggsave(filename = paste0("temp_figs/coefficients/", model, "/", return_type, "_robust_ses/", question, "/ret10_magnitude.jpeg"),
       units = "in", width = 8, height = 5)

#-------------------------------------------------------------------------------
#
# returns 1 day post-headline (with confidence)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()
se_list <- list()
n_list <- list()

outcome = ifelse(return_type == "CAPM", "CAPM_CAR_1", "FF3_CAR_1")

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- lm(data_list[[i]][[outcome]] ~ 
                increase + 
                decrease +
                uncertain +
                increase.confidence +
                decrease.confidence +
                uncertain.confidence - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  } else {
    reg <- lm(data_list[[i]][[outcome]] ~ 
                positive + 
                negative +
                neutral +
                positive.confidence +
                negative.confidence +
                neutral.confidence - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  }
}

# Create custom note with the number of observations
obs_note <- paste("Observations: ", paste(n_list[1:9], collapse = ", "))

# Create stargazer tables
stargazer(reg_list[1:9], type = "latex", se = se_list[1:9], 
          title = paste0(model, " ", question, ": ", "1 Day Post Headline Returns Regressed on Headline Type (with Confidence)"),
          covariate.labels = confidence_labels,
          dep.var.labels = "CAR FD1",
          model.names = TRUE,
          notes = obs_note)

plot_regression_coefficients(reg_list, file_names, paste0("1-day CAR Regression Coefficients with Confidence Intervals (", return_type, ")"))
ggsave(filename = paste0("temp_figs/coefficients/", model, "/", return_type, "_robust_ses/", question, "/ret1_confidence.jpeg"),
       units = "in", width = 8, height = 5)

#-------------------------------------------------------------------------------
#
# returns 5 day post-headline (with confidence)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()
se_list <- list()
n_list <- list()

outcome = ifelse(return_type == "CAPM", "CAPM_CAR_5", "FF3_CAR_5")

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- lm(data_list[[i]][[outcome]] ~ 
                increase + 
                decrease +
                uncertain +
                increase.confidence +
                decrease.confidence +
                uncertain.confidence - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  } else {
    reg <- lm(data_list[[i]][[outcome]] ~ 
                positive + 
                negative +
                neutral +
                positive.confidence +
                negative.confidence +
                neutral.confidence - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  }
}

# Create custom note with the number of observations
obs_note <- paste("Observations: ", paste(n_list[1:9], collapse = ", "))

# Create stargazer tables
stargazer(reg_list[1:9], type = "latex", se = se_list[1:9], 
          title = paste0(model, " ", question, ": ", "5 Day Post Headline Returns Regressed on Headline Type (with Confidence)"),
          covariate.labels = confidence_labels,
          dep.var.labels = "CAR FD5",
          model.names = TRUE,
          notes = obs_note)

plot_regression_coefficients(reg_list, file_names, paste0("5-day CAR Regression Coefficients with Confidence Intervals (", return_type, ")"))
ggsave(filename = paste0("temp_figs/coefficients/", model, "/", return_type, "_robust_ses/", question, "/ret5_confidence.jpeg"),
       units = "in", width = 8, height = 5)

#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (with confidence)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()
se_list <- list()
n_list <- list()

outcome = ifelse(return_type == "CAPM", "CAPM_CAR_10", "FF3_CAR_10")

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- lm(data_list[[i]][[outcome]] ~ 
                increase + 
                decrease +
                uncertain +
                increase.confidence +
                decrease.confidence +
                uncertain.confidence - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  } else {
    reg <- lm(data_list[[i]][[outcome]] ~ 
                positive + 
                negative +
                neutral +
                positive.confidence +
                negative.confidence +
                neutral.confidence - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
    n_list[[i]] <- nobs(reg)
  }
}

# Create custom note with the number of observations
obs_note <- paste("Observations: ", paste(n_list[1:9], collapse = ", "))

# Create stargazer tables
stargazer(reg_list[1:9], type = "latex", se = se_list[1:9], 
          title = paste0(model, " ", question, ": ","10 Day Post Headline Returns Regressed on Headline Type (with Confidence)"),
          covariate.labels = confidence_labels,
          dep.var.labels = "CAR FD10",
          model.names = TRUE,
          notes = obs_note)

plot_regression_coefficients(reg_list, file_names, paste0("10-day CAR Regression Coefficients with Confidence Intervals (", return_type, ")"))
ggsave(filename = paste0("temp_figs/coefficients/", model, "/", return_type, "_robust_ses/", question, "/ret10_confidence.jpeg"),
       units = "in", width = 8, height = 5)
