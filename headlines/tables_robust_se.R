library(dplyr)
library(ggplot2)
library(stargazer)
library(lmtest)
library(sandwich)

rm(list = ls())

# Define the question and the list of months
question <- "q5"
months <- c("jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "octfirst", "octsecond", "nov", "dec")

# Function to read and combine data for all months
read_and_combine <- function(file_name, months, question) {
  combined_df <- data.frame()  # Initialize an empty data frame to store combined data
  for (month in months) {
    file_path <- paste0("./", month, "19/", question, "/", file_name)
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
file_names <- c("base_blanks.csv", "base_json.csv", "cot1.csv", "cot2.csv", "cot3.csv", 
                "persona1.csv", "persona2.csv", "persona3.csv", "persona4.csv")

# Read, combine, and mutate data for all files
combined_data <- lapply(file_names, function(file_name) {
  df <- read_and_combine(file_name, months, question)
  mutate_data(df)
})

# Assign the combined and mutated data to respective variables
base_blanks <- combined_data[[1]]
base_json <- combined_data[[2]]
cot1 <- combined_data[[3]]
cot2 <- combined_data[[4]]
cot3 <- combined_data[[5]]
persona1 <- combined_data[[6]]
persona2 <- combined_data[[7]]
persona3 <- combined_data[[8]]
persona4 <- combined_data[[9]]

rm(combined_data)

# List of datasets
data_list <- list(base_blanks, base_json, persona1, persona2, persona3, persona4, cot1, cot2, cot3)

if (question != "q1") {
  magnitude_labels <- c("Increase", "Decrease", "Uncertain", "Increase Magnitude",
                        "Decrease Magnitude", "Uncertain Magnitude", "Ret LD1", 
                        "Ret LD2", "Ret LD3")
  confidence_labels <- c("Increase", "Decrease", "Uncertain", "Increase Confidence",
                         "Decrease Confidence", "Uncertain Confidence", "Ret LD1", 
                         "Ret LD2", "Ret LD3")
} else {
  magnitude_labels <- c("Positive", "Negative", "Neutral", "Positive Magnitude",
                        "Negative Magnitude", "Neutral Magnitude", "Ret LD1", 
                        "Ret LD2", "Ret LD3")
  confidence_labels <- c("Positive", "Negative", "Neutral", "Positive Confidence",
                         "Negative Confidence", "Neutral Confidence", "Ret LD1", 
                         "Ret LD2", "Ret LD3")
}

#-------------------------------------------------------------------------------
#
# returns 1 day post-headline (with magnitude)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()
se_list <- list()

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- lm(ret_fd1 ~ increase + 
                decrease +
                uncertain +
                increase.magnitude +
                decrease.magnitude +
                uncertain.magnitude +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
  }
  else {
    reg <- lm(ret_fd1 ~ 
                positive + 
                negative +
                neutral +
                positive.magnitude +
                negative.magnitude +
                neutral.magnitude +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
  }
}

# Create stargazer tables
stargazer(reg_list[1:7], type = "text", se = se_list[1:7], 
          title = "1 Day Post Headline Returns Regressed on Headline Type (with Magnitude)",
          covariate.labels = magnitude_labels,
          dep.var.labels = "Return FD1",
          model.names = TRUE)

#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (with magnitude)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()
se_list <- list()

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- lm(ret_fd10 ~ 
                increase + 
                decrease +
                uncertain +
                increase.magnitude +
                decrease.magnitude +
                uncertain.magnitude +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
  } else {
    reg <- lm(ret_fd10 ~ 
                positive + 
                negative +
                neutral +
                positive.magnitude +
                negative.magnitude +
                neutral.magnitude +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
  }
}

# Create stargazer tables
stargazer(reg_list[1:7], type = "text", se = se_list[1:7], 
          title = "10 Day Post Headline Returns Regressed on Headline Type (with Magnitude)",
          covariate.labels = magnitude_labels,
          dep.var.labels = "Return FD10",
          model.names = TRUE)

#-------------------------------------------------------------------------------
#
# returns 1 day post-headline (with confidence)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()
se_list <- list()

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- lm(ret_fd1 ~ 
                increase + 
                decrease +
                uncertain +
                increase.confidence +
                decrease.confidence +
                uncertain.confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
  } else {
    reg <- lm(ret_fd1 ~ 
                positive + 
                negative +
                neutral +
                positive.confidence +
                negative.confidence +
                neutral.confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
  }
}

# Create stargazer tables
stargazer(reg_list[1:7], type = "text", se = se_list[1:7], 
          title = "1 Day Post Headline Returns Regressed on Headline Type (with Confidence)",
          covariate.labels = confidence_labels,
          dep.var.labels = "Return FD1",
          model.names = TRUE)


#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (with confidence)
#
#-------------------------------------------------------------------------------
# Placeholder lists for regression results and standard errors
reg_list <- list()
se_list <- list()

# Run regressions in a loop
for (i in 1:length(data_list)) {
  if (question != "q1") {
    reg <- lm(ret_fd10 ~ 
                increase + 
                decrease +
                uncertain +
                increase.confidence +
                decrease.confidence +
                uncertain.confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
  } else {
    reg <- lm(ret_fd10 ~ 
                positive + 
                negative +
                neutral +
                positive.confidence +
                negative.confidence +
                neutral.confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = data_list[[i]])
    se <- vcovHC(reg, type = "HC1")
    reg <- coeftest(reg, vcov = se)
    
    reg_list[[i]] <- reg
    se_list[[i]] <- se
  }
}


# Create stargazer tables
stargazer(reg_list[1:7], type = "text", se = se_list[1:7], 
          title = "10 Day Post Headline Returns Regressed on Headline Type (with Confidence)",
          covariate.labels = confidence_labels,
          dep.var.labels = "Return FD10",
          model.names = TRUE)
