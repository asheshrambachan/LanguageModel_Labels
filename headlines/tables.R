library(dplyr)
library(ggplot2)
library(stargazer)
library(lmtest)
library(sandwich)

rm(list = ls())

# Define the question and the list of months
question <- "q2"
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
  if (question == "q2") {
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

#-------------------------------------------------------------------------------
#
# returns 1 day post-headline (with magnitude)
#
#-------------------------------------------------------------------------------
reg1.1m <- lm(ret_fd1 ~ increase + 
                        decrease +
                        uncertain +
                        increase.magnitude +
                        decrease.magnitude +
                        uncertain.magnitude +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                        data = base_blanks)
se1.1m <- vcovHC(reg1.1m, type = "HC1")
reg1.1m <- coeftest(reg1.1m, vcov = se1.1m)

reg2.1m <-  lm(ret_fd1 ~ increase + 
                 decrease +
                 uncertain +
                 increase.magnitude +
                 decrease.magnitude +
                 uncertain.magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = base_json)
se2.1m <- vcovHC(reg2.1m, type = "HC1")
reg2.1m <- coeftest(reg2.1m, vcov = se2.1m)

reg3.1m <-  lm(ret_fd1 ~ increase + 
                 decrease +
                 uncertain +
                 increase.magnitude +
                 decrease.magnitude +
                 uncertain.magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = persona1)
se3.1m <- vcovHC(reg3.1m, type = "HC1")
reg3.1m <- coeftest(reg3.1m, vcov = se3.1m)

reg4.1m <-  lm(ret_fd1 ~ increase + 
                 decrease +
                 uncertain +
                 increase.magnitude +
                 decrease.magnitude +
                 uncertain.magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = persona2)
se4.1m <- vcovHC(reg4.1m, type = "HC1")
reg4.1m <- coeftest(reg4.1m, vcov = se4.1m)

reg5.1m <-  lm(ret_fd1 ~ increase + 
                 decrease +
                 uncertain +
                 increase.magnitude +
                 decrease.magnitude +
                 uncertain.magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = persona3)
se5.1m <- vcovHC(reg5.1m, type = "HC1")
reg5.1m <- coeftest(reg5.1m, vcov = se5.1m)

reg6.1m <-  lm(ret_fd1 ~ increase + 
                 decrease +
                 uncertain +
                 increase.magnitude +
                 decrease.magnitude +
                 uncertain.magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = persona4)
se6.1m <- vcovHC(reg6.1m, type = "HC1")
reg6.1m <- coeftest(reg6.1m, vcov = se6.1m)

reg7.1m <-  lm(ret_fd1 ~ increase + 
                 decrease +
                 uncertain +
                 increase.magnitude +
                 decrease.magnitude +
                 uncertain.magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = cot1)
se7.1m <- vcovHC(reg7.1m, type = "HC1")
reg7.1m <- coeftest(reg7.1m, vcov = se7.1m)

reg8.1m <-  lm(ret_fd1 ~ increase + 
                 decrease +
                 uncertain +
                 increase.magnitude +
                 decrease.magnitude +
                 uncertain.magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = cot2)
se8.1m <- vcovHC(reg8.1m, type = "HC1")
reg8.1m <- coeftest(reg8.1m, vcov = se8.1m)

reg9.1m <-  lm(ret_fd1 ~ increase + 
                 decrease +
                 uncertain +
                 increase.magnitude +
                 decrease.magnitude +
                 uncertain.magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = cot3)
se9.1m <- vcovHC(reg9.1m, type = "HC1")
reg9.1m <- coeftest(reg9.1m, vcov = se9.1m)

# stargazer can't handle more than 7 models so I took out the last 2 for now
stargazer(reg1.1m, reg2.1m, reg3.1m, reg4.1m, reg5.1m, reg6.1m, reg7.1m,
          se = list(se1.1m, se2.1m, se3.1m, se4.1m, se5.1m, se6.1m, se7.1m))

stargazer(reg8.1m, reg9.1m,
          se = list(se8.1m, se9.1m))

#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (with magnitude)
#
#-------------------------------------------------------------------------------
reg1.10m <- lm(ret_fd10 ~ 
                increase +
                decrease + 
                uncertain +
                increase*magnitude +
                decrease*magnitude +
                uncertain*magnitude +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se1.10m <- vcovHC(reg1.10m, type = "HC1")
reg1.10m <- coeftest(reg1.10m, vcov = se1.10m)

reg2.10m <- lm(ret_fd10 ~ 
                 increase +
                 decrease + 
                 uncertain +
                 increase*magnitude +
                 decrease*magnitude +
                 uncertain*magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = base_json)
se2.10m <- vcovHC(reg2.10m, type = "HC1")
reg2.10m <- coeftest(reg2.10m, vcov = se2.10m)

reg3.10m <- lm(ret_fd10 ~ 
                 increase +
                 decrease + 
                 uncertain +
                 increase*magnitude +
                 decrease*magnitude +
                 uncertain*magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
              data = persona1)
se3.10m <- vcovHC(reg3.10m, type = "HC1")
reg3.10m <- coeftest(reg3.10m, vcov = se3.10m)

reg4.10m <- lm(ret_fd10 ~ 
                 increase +
                 decrease + 
                 uncertain +
                 increase*magnitude +
                 decrease*magnitude +
                 uncertain*magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = persona2)
se4.10m <- vcovHC(reg4.10m, type = "HC1")
reg4.10m <- coeftest(reg4.10m, vcov = se4.10m)

reg5.10m <- lm(ret_fd10 ~ 
                 increase +
                 decrease + 
                 uncertain +
                 increase*magnitude +
                 decrease*magnitude +
                 uncertain*magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = persona3)
se5.10m <- vcovHC(reg5.10m, type = "HC1")
reg5.10m <- coeftest(reg5.10m, vcov = se5.10m)

reg6.10m <- lm(ret_fd10 ~ 
                 increase +
                 decrease + 
                 uncertain +
                 increase*magnitude +
                 decrease*magnitude +
                 uncertain*magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = persona4)
se6.10m <- vcovHC(reg6.10m, type = "HC1")
reg6.10m <- coeftest(reg6.10m, vcov = se6.10m)

reg7.10m <- lm(ret_fd10 ~ 
                 increase +
                 decrease + 
                 uncertain +
                 increase*magnitude +
                 decrease*magnitude +
                 uncertain*magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = cot1)
se7.10m <- vcovHC(reg7.10m, type = "HC1")
reg7.10m <- coeftest(reg7.10m, vcov = se7.10m)

reg8.10m <- lm(ret_fd10 ~ 
                 increase +
                 decrease + 
                 uncertain +
                 increase*magnitude +
                 decrease*magnitude +
                 uncertain*magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = cot2)
se8.10m <- vcovHC(reg8.10m, type = "HC1")
reg8.10m <- coeftest(reg8.10m, vcov = se8.10m)

reg9.10m <- lm(ret_fd10 ~ 
                 increase +
                 decrease + 
                 uncertain +
                 increase*magnitude +
                 decrease*magnitude +
                 uncertain*magnitude +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = cot3)
se9.10m <- vcovHC(reg9.10m, type = "HC1")
reg9.10m <- coeftest(reg9.10m, vcov = se9.10m)

# I report a transposed version of this table (transposed by chatGPT)
# set type to "text" so it's easily displayed, will change back to latex
# stargazer can't handle more than 7 models so I took out the last 2 for now
stargazer(reg1.10m, reg2.10m, reg3.10m, reg4.10m, reg5.10m, reg6.10m, reg7.10m,
          se = list(se1.10m, se2.10m, se3.10m, se4.10m, se5.10m, se6.10m, se7.10m),
          type = "text")

#-------------------------------------------------------------------------------
#
# returns 1 day post-headline (with confidence)
#
#-------------------------------------------------------------------------------
reg1.1c <- lm(ret_fd1 ~ increase*confidence +
                decrease*confidence +
                uncertain*confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se1.1c <- vcovHC(reg1.1c, type = "HC1")
reg1.1c <- coeftest(reg1.1c, vcov = se1.1c)

reg2.1c <- lm(ret_fd1 ~ increase*confidence +
                decrease*confidence +
                uncertain*confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se2.1c <- vcovHC(reg2.1c, type = "HC1")
reg2.1c <- coeftest(reg2.1c, vcov = se2.1c)

reg3.1c <- lm(ret_fd1 ~ increase*confidence +
                decrease*confidence +
                uncertain*confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se3.1c <- vcovHC(reg3.1c, type = "HC1")
reg3.1c <- coeftest(reg3.1c, vcov = se3.1c)

reg4.1c <- lm(ret_fd1 ~ increase*confidence +
                decrease*confidence +
                uncertain*confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se4.1c <- vcovHC(reg4.1c, type = "HC1")
reg4.1c <- coeftest(reg4.1c, vcov = se4.1c)

reg5.1c <- lm(ret_fd1 ~ increase*confidence +
                decrease*confidence +
                uncertain*confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se5.1c <- vcovHC(reg5.1c, type = "HC1")
reg5.1c <- coeftest(reg5.1c, vcov = se5.1c)

reg6.1c <- lm(ret_fd1 ~ increase*confidence +
                decrease*confidence +
                uncertain*confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se6.1c <- vcovHC(reg6.1c, type = "HC1")
reg6.1c <- coeftest(reg6.1c, vcov = se6.1c)

reg7.1c <- lm(ret_fd1 ~ increase*confidence +
                decrease*confidence +
                uncertain*confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se7.1c <- vcovHC(reg7.1c, type = "HC1")
reg7.1c <- coeftest(reg7.1c, vcov = se7.1c)

reg8.1c <- lm(ret_fd1 ~ increase*confidence +
                decrease*confidence +
                uncertain*confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se8.1c <- vcovHC(reg8.1c, type = "HC1")
reg8.1c <- coeftest(reg8.1c, vcov = se8.1c)

reg9.1c <- lm(ret_fd1 ~ increase*confidence +
                decrease*confidence +
                uncertain*confidence +
                ret_ld1 +
                ret_ld2 +
                ret_ld3 - 1,
              data = base_blanks)
se9.1c <- vcovHC(reg9.1c, type = "HC1")
reg9.1c <- coeftest(reg9.1c, vcov = se9.1c)

# I report a transposed version of this table (transposed by chatGPT)
# set type to "text" so it's easily displayed, will change back to latex
# stargazer can't handle more than 7 models so I took out the last 2 for now
stargazer(reg1.1c, reg2.1c, reg3.1c, reg4.1c, reg5.1c, reg6.1c, reg7.1c,
          se = list(se1.1c, se2.1c, se3.1c, se4.1c, se5.1c, se6.1c, se7.1c),
          type = "text")

#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (with confidence)
#
#-------------------------------------------------------------------------------
reg1.10c <- lm(ret_fd1 ~ increase*confidence +
                 decrease*confidence +
                 uncertain*confidence +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = base_blanks)
se1.10c <- vcovHC(reg1.10c, type = "HC1")
reg1.10c <- coeftest(reg1.10c, vcov = se1.10c)

reg2.10c <- lm(ret_fd1 ~ increase*confidence +
                 decrease*confidence +
                 uncertain*confidence +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = base_blanks)
se2.10c <- vcovHC(reg2.10c, type = "HC1")
reg2.10c <- coeftest(reg2.10c, vcov = se2.10c)

reg3.10c <- lm(ret_fd1 ~ increase*confidence +
                 decrease*confidence +
                 uncertain*confidence +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = base_blanks)
se3.10c <- vcovHC(reg3.10c, type = "HC1")
reg3.10c <- coeftest(reg3.10c, vcov = se3.10c)

reg4.10c <- lm(ret_fd1 ~ increase*confidence +
                 decrease*confidence +
                 uncertain*confidence +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = base_blanks)
se4.10c <- vcovHC(reg4.10c, type = "HC1")
reg4.10c <- coeftest(reg4.10c, vcov = se4.10c)

reg5.10c <- lm(ret_fd1 ~ increase*confidence +
                 decrease*confidence +
                 uncertain*confidence +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = base_blanks)
se5.10c <- vcovHC(reg5.10c, type = "HC1")
reg5.10c <- coeftest(reg5.10c, vcov = se5.10c)

reg6.10c <- lm(ret_fd1 ~ increase*confidence +
                 decrease*confidence +
                 uncertain*confidence +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = base_blanks)
se6.10c <- vcovHC(reg6.10c, type = "HC1")
reg6.10c <- coeftest(reg6.10c, vcov = se6.10c)

reg7.10c <- lm(ret_fd1 ~ increase*confidence +
                 decrease*confidence +
                 uncertain*confidence +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = base_blanks)
se7.10c <- vcovHC(reg7.10c, type = "HC1")
reg7.10c <- coeftest(reg7.10c, vcov = se7.10c)

reg8.10c <- lm(ret_fd1 ~ increase*confidence +
                 decrease*confidence +
                 uncertain*confidence +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = base_blanks)
se8.10c <- vcovHC(reg8.10c, type = "HC1")
reg8.10c <- coeftest(reg8.10c, vcov = se8.10c)

reg9.10c <- lm(ret_fd1 ~ increase*confidence +
                 decrease*confidence +
                 uncertain*confidence +
                 ret_ld1 +
                 ret_ld2 +
                 ret_ld3 - 1,
               data = base_blanks)
se9.10c <- vcovHC(reg9.10c, type = "HC1")
reg9.10c <- coeftest(reg9.10c, vcov = se9.10c)

# I report a transposed version of this table (transposed by chatGPT)
# set type to "text" so it's easily displayed, will change back to latex
# stargazer can't handle more than 7 models so I took out the last 2 for now
stargazer(reg1.10c, reg2.10c, reg3.10c, reg4.10c, reg5.10c, reg6.10c, reg7.10c,
          se = list(se1.10c, se2.10c, se3.10c, se4.10c, se5.10c, se6.10c, se7.10c),
          type = "text")


# #-------------------------------------------------------------------------------
# #
# # returns 1 day post-headline (with magnitude)
# #
# #-------------------------------------------------------------------------------
# reg1.1m <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.magnitude +
#                 negative.magnitude +
#                 neutral.magnitude +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = base_blanks)
# se1.1m <- vcovHC(reg1.1m, type = "HC1")
# reg1.1m <- coeftest(reg1.1m, vcov = se1.1m)
# 
# reg2.1m <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.magnitude +
#                 negative.magnitude +
#                 neutral.magnitude +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = base_json)
# se2.1m <- vcovHC(reg2.1m, type = "HC1")
# reg2.1m <- coeftest(reg2.1m, vcov = se2.1m)
# 
# reg3.1m <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.magnitude +
#                 negative.magnitude +
#                 neutral.magnitude +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = persona1)
# se3.1m <- vcovHC(reg3.1m, type = "HC1")
# reg3.1m <- coeftest(reg3.1m, vcov = se3.1m)
# 
# reg4.1m <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.magnitude +
#                 negative.magnitude +
#                 neutral.magnitude +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = persona2)
# se4.1m <- vcovHC(reg4.1m, type = "HC1")
# reg4.1m <- coeftest(reg4.1m, vcov = se4.1m)
# 
# reg5.1m <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.magnitude +
#                 negative.magnitude +
#                 neutral.magnitude +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = persona3)
# se5.1m <- vcovHC(reg5.1m, type = "HC1")
# reg5.1m <- coeftest(reg5.1m, vcov = se5.1m)
# 
# reg6.1m <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.magnitude +
#                 negative.magnitude +
#                 neutral.magnitude +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = persona4)
# se6.1m <- vcovHC(reg6.1m, type = "HC1")
# reg6.1m <- coeftest(reg6.1m, vcov = se6.1m)
# 
# reg7.1m <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.magnitude +
#                 negative.magnitude +
#                 neutral.magnitude +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = cot1)
# se7.1m <- vcovHC(reg7.1m, type = "HC1")
# reg7.1m <- coeftest(reg7.1m, vcov = se7.1m)
# 
# reg8.1m <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.magnitude +
#                 negative.magnitude +
#                 neutral.magnitude +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = cot2)
# se8.1m <- vcovHC(reg8.1m, type = "HC1")
# reg8.1m <- coeftest(reg8.1m, vcov = se8.1m)
# 
# reg9.1m <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.magnitude +
#                 negative.magnitude +
#                 neutral.magnitude +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = cot3)
# se9.1m <- vcovHC(reg9.1m, type = "HC1")
# reg9.1m <- coeftest(reg9.1m, vcov = se9.1m)
# 
# # I report a transposed version of this table (transposed by chatGPT)
# # set type to "text" so it's easily displayed, will change back to latex
# # stargazer can't handle more than 7 models so I took out the last 2 for now
# stargazer(reg1.1m, reg2.1m, reg3.1m, reg4.1m, reg5.1m, reg6.1m, reg7.1m,
#           se = list(se1.1m, se2.1m, se3.1m, se4.1m, se5.1m, se6.1m, se7.1m))
# 
# stargazer(reg8.1m, reg9.1m,
#           se = list(se8.1m, se9.1m))
# 
# #-------------------------------------------------------------------------------
# #
# # returns 10 day post-headline (with magnitude)
# #
# #-------------------------------------------------------------------------------
# reg1.10m <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.magnitude +
#                  negative.magnitude +
#                  neutral.magnitude +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = base_blanks)
# se1.10m <- vcovHC(reg1.10m, type = "HC1")
# reg1.10m <- coeftest(reg1.10m, vcov = se1.10m)
# 
# reg2.10m <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.magnitude +
#                  negative.magnitude +
#                  neutral.magnitude +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = base_json)
# se2.10m <- vcovHC(reg2.10m, type = "HC1")
# reg2.10m <- coeftest(reg2.10m, vcov = se2.10m)
# 
# reg3.10m <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.magnitude +
#                  negative.magnitude +
#                  neutral.magnitude +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = persona1)
# se3.10m <- vcovHC(reg3.10m, type = "HC1")
# reg3.10m <- coeftest(reg3.10m, vcov = se3.10m)
# 
# reg4.10m <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.magnitude +
#                  negative.magnitude +
#                  neutral.magnitude +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = persona2)
# se4.10m <- vcovHC(reg4.10m, type = "HC1")
# reg4.10m <- coeftest(reg4.10m, vcov = se4.10m)
# 
# reg5.10m <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.magnitude +
#                  negative.magnitude +
#                  neutral.magnitude +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = persona3)
# se5.10m <- vcovHC(reg5.10m, type = "HC1")
# reg5.10m <- coeftest(reg5.10m, vcov = se5.10m)
# 
# reg6.10m <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.magnitude +
#                  negative.magnitude +
#                  neutral.magnitude +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = persona4)
# se6.10m <- vcovHC(reg6.10m, type = "HC1")
# reg6.10m <- coeftest(reg6.10m, vcov = se6.10m)
# 
# reg7.10m <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.magnitude +
#                  negative.magnitude +
#                  neutral.magnitude +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = cot1)
# se7.10m <- vcovHC(reg7.10m, type = "HC1")
# reg7.10m <- coeftest(reg7.10m, vcov = se7.10m)
# 
# reg8.10m <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.magnitude +
#                  negative.magnitude +
#                  neutral.magnitude +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = cot2)
# se8.10m <- vcovHC(reg8.10m, type = "HC1")
# reg8.10m <- coeftest(reg8.10m, vcov = se8.10m)
# 
# reg9.10m <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.magnitude +
#                  negative.magnitude +
#                  neutral.magnitude +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = cot3)
# se9.10m <- vcovHC(reg9.10m, type = "HC1")
# reg9.10m <- coeftest(reg9.10m, vcov = se9.10m)
# 
# # I report a transposed version of this table (transposed by chatGPT)
# # set type to "text" so it's easily displayed, will change back to latex
# # stargazer can't handle more than 7 models so I took out the last 2 for now
# stargazer(reg1.10m, reg2.10m, reg3.10m, reg4.10m, reg5.10m, reg6.10m,
#           se = list(se1.10m, se2.10m, se3.10m, se4.10m, se5.10m, se6.10m))
# 
# stargazer(reg7.10m, reg8.10m, reg9.10m,
#           se = list(se7.10m, se8.10m, se9.10m))
# 
# #-------------------------------------------------------------------------------
# #
# # returns 1 day post-headline (with confidence)
# #
# #-------------------------------------------------------------------------------
# reg1.1c <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.confidence +
#                 negative.confidence +
#                 neutral.confidence +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = base_blanks)
# se1.1c <- vcovHC(reg1.1c, type = "HC1")
# reg1.1c <- coeftest(reg1.1c, vcov = se1.1c)
# 
# reg2.1c <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.confidence +
#                 negative.confidence +
#                 neutral.confidence +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = base_json)
# se2.1c <- vcovHC(reg2.1c, type = "HC1")
# reg2.1c <- coeftest(reg2.1c, vcov = se2.1c)
# 
# reg3.1c <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.confidence +
#                 negative.confidence +
#                 neutral.confidence +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = persona1)
# se3.1c <- vcovHC(reg3.1c, type = "HC1")
# reg3.1c <- coeftest(reg3.1c, vcov = se3.1c)
# 
# reg4.1c <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.confidence +
#                 negative.confidence +
#                 neutral.confidence +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = persona2)
# se4.1c <- vcovHC(reg4.1c, type = "HC1")
# reg4.1c <- coeftest(reg4.1c, vcov = se4.1c)
# 
# reg5.1c <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.confidence +
#                 negative.confidence +
#                 neutral.confidence +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = persona3)
# se5.1c <- vcovHC(reg5.1c, type = "HC1")
# reg5.1c <- coeftest(reg5.1c, vcov = se5.1c)
# 
# reg6.1c <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.confidence +
#                 negative.confidence +
#                 neutral.confidence +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = persona4)
# se6.1c <- vcovHC(reg6.1c, type = "HC1")
# reg6.1c <- coeftest(reg6.1c, vcov = se6.1c)
# 
# reg7.1c <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.confidence +
#                 negative.confidence +
#                 neutral.confidence +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = cot1)
# se7.1c <- vcovHC(reg7.1c, type = "HC1")
# reg7.1c <- coeftest(reg7.1c, vcov = se7.1c)
# 
# reg8.1c <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.confidence +
#                 negative.confidence +
#                 neutral.confidence +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = cot2)
# se8.1c <- vcovHC(reg8.1c, type = "HC1")
# reg8.1c <- coeftest(reg8.1c, vcov = se8.1c)
# 
# reg9.1c <- lm(ret_fd1 ~
#                 positive +
#                 negative + 
#                 neutral +
#                 positive.confidence +
#                 negative.confidence +
#                 neutral.confidence +
#                 ret_ld1 +
#                 ret_ld2 +
#                 ret_ld3 - 1,
#               data = cot3)
# se9.1c <- vcovHC(reg9.1c, type = "HC1")
# reg9.1c <- coeftest(reg9.1c, vcov = se9.1c)
# 
# # I report a transposed version of this table (transposed by chatGPT)
# # set type to "text" so it's easily displayed, will change back to latex
# # stargazer can't handle more than 7 models so I took out the last 2 for now
# stargazer(reg1.1c, reg2.1c, reg3.1c, reg4.1c, reg5.1c, reg6.1c, reg7.1c,
#           se = list(se1.1c, se2.1c, se3.1c, se4.1c, se5.1c, se6.1c, se7.1c))
# stargazer(reg8.1c, reg9.1c,
#           se = list(se8.1c, se9.1c))
# 
# #-------------------------------------------------------------------------------
# #
# # returns 10 day post-headline (with confidence)
# #
# #-------------------------------------------------------------------------------
# reg1.10c <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.confidence +
#                  negative.confidence +
#                  neutral.confidence +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = base_blanks)
# se1.10c <- vcovHC(reg1.10c, type = "HC1")
# reg1.10c <- coeftest(reg1.10c, vcov = se1.10c)
# 
# reg2.10c <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.confidence +
#                  negative.confidence +
#                  neutral.confidence +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = base_json)
# se2.10c <- vcovHC(reg2.10c, type = "HC1")
# reg2.10c <- coeftest(reg2.10c, vcov = se2.10c)
# 
# reg3.10c <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.confidence +
#                  negative.confidence +
#                  neutral.confidence +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = persona1)
# se3.10c <- vcovHC(reg3.10c, type = "HC1")
# reg3.10c <- coeftest(reg3.10c, vcov = se3.10c)
# 
# reg4.10c <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.confidence +
#                  negative.confidence +
#                  neutral.confidence +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = persona2)
# se4.10c <- vcovHC(reg4.10c, type = "HC1")
# reg4.10c <- coeftest(reg4.10c, vcov = se4.10c)
# 
# reg5.10c <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.confidence +
#                  negative.confidence +
#                  neutral.confidence +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = persona3)
# se5.10c <- vcovHC(reg5.10c, type = "HC1")
# reg5.10c <- coeftest(reg5.10c, vcov = se5.10c)
# 
# reg6.10c <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.confidence +
#                  negative.confidence +
#                  neutral.confidence +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = persona4)
# se6.10c <- vcovHC(reg6.10c, type = "HC1")
# reg6.10c <- coeftest(reg6.10c, vcov = se6.10c)
# 
# reg7.10c <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.confidence +
#                  negative.confidence +
#                  neutral.confidence +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = cot1)
# se7.10c <- vcovHC(reg7.10c, type = "HC1")
# reg7.10c <- coeftest(reg7.10c, vcov = se7.10c)
# 
# reg8.10c <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.confidence +
#                  negative.confidence +
#                  neutral.confidence +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = cot2)
# se8.10c <- vcovHC(reg8.10c, type = "HC1")
# reg8.10c <- coeftest(reg8.10c, vcov = se8.10c)
# 
# reg9.10c <- lm(ret_fd10 ~
#                  positive +
#                  negative + 
#                  neutral +
#                  positive.confidence +
#                  negative.confidence +
#                  neutral.confidence +
#                  ret_ld1 +
#                  ret_ld2 +
#                  ret_ld3 - 1,
#                data = cot3)
# se9.10c <- vcovHC(reg9.10c, type = "HC1")
# reg9.10c <- coeftest(reg9.10c, vcov = se9.10c)
# 
# # I report a transposed version of this table (transposed by chatGPT)
# # set type to "text" so it's easily displayed, will change back to latex
# # stargazer can't handle more than 7 models so I took out the last 2 for now
# stargazer(reg1.10c, reg2.10c, reg3.10c, reg4.10c, reg5.10c, reg6.10c,
#           se = list(se1.10c, se2.10c, se3.10c, se4.10c, se5.10c, se6.10c))
# stargazer(reg7.10c, reg8.10c, reg9.10c,
#           se = list(se7.10c, se8.10c, se9.10c))
