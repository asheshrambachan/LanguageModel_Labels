library(dplyr)
library(ggplot2)
library(stargazer)
library(sandwich)

# Define the question and the list of months
question <- "q1"
months <- c("jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "nov", "dec")

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

# Read and combine data for all months
base_blanks <- read_and_combine("base_blanks.csv", months, question)
base_json <- read_and_combine("base_json.csv", months, question)
cot1 <- read_and_combine("cot1.csv", months, question)
cot2 <- read_and_combine("cot2.csv", months, question)
cot3 <- read_and_combine("cot3.csv", months, question)
persona1 <- read_and_combine("persona1.csv", months, question)
persona2 <- read_and_combine("persona2.csv", months, question)
persona3 <- read_and_combine("persona3.csv", months, question)
persona4 <- read_and_combine("persona4.csv", months, question)

#-------------------------------------------------------------------------------
#
# returns 1 day post-headline (no magnitude or confidence) 
#
#-------------------------------------------------------------------------------

reg1 <- lm(ret_fd1 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = base_blanks)
se1 <- vcovHC(reg1, type = "HC1")
reg1 <- coeftest(reg1, vcov = se1)

reg2 <- lm(ret_fd1 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3  - 1, data = base_json)
se2 <- vcovHC(reg2, type = "HC1")
reg2 <- coeftest(reg2, vcov = se2)

reg3 <- lm(ret_fd1 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona1)
se3 <- vcovHC(reg3, type = "HC1")
reg3 <- coeftest(reg3, vcov = se3)

reg4 <- lm(ret_fd1 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona2)
se4 <- vcovHC(reg4, type = "HC1")
reg4 <- coeftest(reg4, vcov = se4)

reg5 <- lm(ret_fd1 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona3)
se5 <- vcovHC(reg5, type = "HC1")
reg5 <- coeftest(reg5, vcov = se5)

reg6 <- lm(ret_fd1 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona4)
se6 <- vcovHC(reg6, type = "HC1")
reg6 <- coeftest(reg6, vcov = se6)

reg7 <- lm(ret_fd1 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot1)
se7 <- vcovHC(reg7, type = "HC1")
reg7 <- coeftest(reg7, vcov = se7)

reg8 <- lm(ret_fd1 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot2)
se8 <- vcovHC(reg8, type = "HC1")
reg8 <- coeftest(reg8, vcov = se8)

reg9 <- lm(ret_fd1 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot3)
se9 <- vcovHC(reg9, type = "HC1")
reg9 <- coeftest(reg9, vcov = se9)

# I report a transposed version of this table (transposed by chatGPT)
# set type to "text" so it's easily displayed, will change back to latex
stargazer(reg1, reg2, reg3, reg4, reg5, reg6, reg7, reg8, reg9,
          se = list(se1, se2, se3, se4, se5, se6, se7, se8, se9),
          type = "text")

#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (no magnitude or confidence) 
#
#-------------------------------------------------------------------------------

reg1.1 <- lm(ret_fd10 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = base_blanks)
se1.1 <- vcovHC(reg1.1, type = "HC1")
reg1.1 <- coeftest(reg1.1, vcov = se1.1)

reg2.1 <- lm(ret_fd10 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = base_json)
se2.1 <- vcovHC(reg2.1, type = "HC1")
reg2.1 <- coeftest(reg2.1, vcov = se2.1)

reg3.1 <- lm(ret_fd10 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona1)
se3.1 <- vcovHC(reg3.1, type = "HC1")
reg3.1 <- coeftest(reg3.1, vcov = se3.1)

reg4.1 <- lm(ret_fd10 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona2)
se4.1 <- vcovHC(reg4.1, type = "HC1")
reg4.1 <- coeftest(reg4.1, vcov = se4.1)

reg5.1 <- lm(ret_fd10 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona3)
se5.1 <- vcovHC(reg5.1, type = "HC1")
reg5.1 <- coeftest(reg5.1, vcov = se5.1)

reg6.1 <- lm(ret_fd10 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona4)
se6.1 <- vcovHC(reg6.1, type = "HC1")
reg6.1 <- coeftest(reg6.1, vcov = se6.1)

reg7.1 <- lm(ret_fd10 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3  - 1,  data = cot1)
se7.1 <- vcovHC(reg7.1, type = "HC1")
reg7.1 <- coeftest(reg7.1, vcov = se7.1)

reg8.1 <- lm(ret_fd10 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot2)
se8.1 <- vcovHC(reg8.1, type = "HC1")
reg8.1 <- coeftest(reg8.1, vcov = se8.1)

reg9.1 <- lm(ret_fd10 ~ headline.type + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot3)
se9.1 <- vcovHC(reg9.1, type = "HC1")
reg9.1 <- coeftest(reg9.1, vcov = se9.1)


# I report a transposed version of this table (transposed by chatGPT)
# set type to "text" so it's easily displayed, will change back to latex
# stargazer can't handle more than 7 models so I took out the last 2 for now
stargazer(reg1.1, reg2.1, reg3.1, reg4.1, reg5.1, reg6.1, reg7.1,
          se = list(se1.1, se2.1, se3.1, se4.1, se5.1, se6.1, se7.1),
          type = "text")

#-------------------------------------------------------------------------------
#
# returns 1 day post-headline (with magnitude) 
#
#-------------------------------------------------------------------------------
reg1.2 <- lm(ret_fd1 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = base_blanks)
se1.2 <- vcovHC(reg1.2, type = "HC1")
reg1.2 <- coeftest(reg1.2, vcov = se1.2)

reg2.2 <- lm(ret_fd1 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1, data = base_json)
se2.2 <- vcovHC(reg2.2, type = "HC1")
reg2.2 <- coeftest(reg2.2, vcov = se2.2)

reg3.2 <- lm(ret_fd1 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona1)
se3.2 <- vcovHC(reg3.2, type = "HC1")
reg3.2 <- coeftest(reg3.2, vcov = se3.2)

reg4.2 <- lm(ret_fd1 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona2)
se4.2 <- vcovHC(reg4.2, type = "HC1")
reg4.2 <- coeftest(reg4.2, vcov = se4.2)

reg5.2 <- lm(ret_fd1 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona3)
se5.2 <- vcovHC(reg5.2, type = "HC1")
reg5.2 <- coeftest(reg5.2, vcov = se5.2)

reg6.2 <- lm(ret_fd1 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona4)
se6.2 <- vcovHC(reg6.2, type = "HC1")
reg6.2 <- coeftest(reg6.2, vcov = se6.2)

reg7.2 <- lm(ret_fd1 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot1)
se7.2 <- vcovHC(reg7.2, type = "HC1")
reg7.2 <- coeftest(reg7.2, vcov = se7.2)

reg8.2 <- lm(ret_fd1 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot2)
se8.2 <- vcovHC(reg8.2, type = "HC1")
reg8.2 <- coeftest(reg8.2, vcov = se8.2)

reg9.2 <- lm(ret_fd1 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot3)
se9.2 <- vcovHC(reg9.2, type = "HC1")
reg9.2 <- coeftest(reg9.2, vcov = se9.2)

# I report a transposed version of this table (transposed by chatGPT)
# set type to "text" so it's easily displayed, will change back to latex
# stargazer can't handle more than 7 models so I took out the last 2 for now
stargazer(reg1.2, reg2.2, reg3.2, reg4.2, reg5.2, reg6.2, reg7.2,
          se = list(se1.2, se2.2, se3.2, se4.2, se5.2, se6.2, se7.2),
          type = "text")

#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (with magnitude) 
#
#-------------------------------------------------------------------------------
reg1.3 <- lm(ret_fd10 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = base_blanks)
se1.3 <- vcovHC(reg1.3, type = "HC1")
reg1.3 <- coeftest(reg1.3, vcov = se1.3)

reg2.3 <- lm(ret_fd10 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = base_json)
se2.3 <- vcovHC(reg2.3, type = "HC1")
reg2.3 <- coeftest(reg2.3, vcov = se2.3)

reg3.3 <- lm(ret_fd10 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona1)
se3.3 <- vcovHC(reg3.3, type = "HC1")
reg3.3 <- coeftest(reg3.3, vcov = se3.3)

reg4.3 <- lm(ret_fd10 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona2)
se4.3 <- vcovHC(reg4.3, type = "HC1")
reg4.3 <- coeftest(reg4.3, vcov = se4.3)

reg5.3 <- lm(ret_fd10 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona3)
se5.3 <- vcovHC(reg5.3, type = "HC1")
reg5.3 <- coeftest(reg5.3, vcov = se5.3)

reg6.3 <- lm(ret_fd10 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona4)
se6.3 <- vcovHC(reg6.3, type = "HC1")
reg6.3 <- coeftest(reg6.3, vcov = se6.3)

reg7.3 <- lm(ret_fd10 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot1)
se7.3 <- vcovHC(reg7.3, type = "HC1")
reg7.3 <- coeftest(reg7.3, vcov = se7.3)

reg8.3 <- lm(ret_fd10 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot2)
se8.3 <- vcovHC(reg8.3, type = "HC1")
reg8.3 <- coeftest(reg8.3, vcov = se8.2)

reg9.3 <- lm(ret_fd10 ~ headline.type * magnitude + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot3)
se9.3 <- vcovHC(reg9.3, type = "HC1")
reg9.3 <- coeftest(reg9.3, vcov = se9.3)

# I report a transposed version of this table (transposed by chatGPT)
# set type to "text" so it's easily displayed, will change back to latex
# stargazer can't handle more than 7 models so I took out the last 2 for now
stargazer(reg1.3, reg2.3, reg3.3, reg4.3, reg5.3, reg6.3, reg7.3,
          se = list(se1.3, se2.3, se3.3, se4.3, se5.3, se6.3, se7.2),
          type = "text")

#-------------------------------------------------------------------------------
#
# returns 1 day post-headline (with confidence) 
#
#-------------------------------------------------------------------------------
reg1.4 <- lm(ret_fd1 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = base_blanks)
se1.4 <- vcovHC(reg1.4, type = "HC1")
reg1.4 <- coeftest(reg1.4, vcov = se1.4)

reg2.4 <- lm(ret_fd1 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1, data = base_json)
se2.4 <- vcovHC(reg2.4, type = "HC1")
reg2.4 <- coeftest(reg2.4, vcov = se2.4)

reg3.4 <- lm(ret_fd1 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona1)
se3.4 <- vcovHC(reg3.4, type = "HC1")
reg3.4 <- coeftest(reg3.4, vcov = se3.4)

persona1 <- persona1 %>%
  mutate(decrease = ifelse(headline.type == "decrease", 1, 0),
         increase = ifelse(headline.type == "increase", 1, 0),
         uncertain = ifelse(headline.type == "uncertain", 1, 0),
         decrease.confidence = decrease * confidence,
         increase.confidence = increase * confidence,
         uncertain.confidence = uncertain * confidence )

persona2 <- persona2 %>%
  mutate(decrease = ifelse(headline.type == "decrease", 1, 0),
         increase = ifelse(headline.type == "increase", 1, 0),
         uncertain = ifelse(headline.type == "uncertain", 1, 0),
         decrease.confidence = decrease * confidence,
         increase.confidence = increase * confidence,
         uncertain.confidence = uncertain * confidence )

# not missing
reg3.4 <- lm(ret_fd1 ~ decrease + increase + uncertain + decrease.confidence + 
               increase.confidence + uncertain.confidence - 1, data = persona1)
se3.4 <- vcovHC(reg3.4, type = "HC1")
reg3.4 <- coeftest(reg3.4, vcov = se3.4)
reg3.4


# missing 
reg4.4 <- lm(ret_fd1 ~ decrease + increase + uncertain + decrease.confidence + 
               increase.confidence + uncertain.confidence - 1, data = persona2)
se4.4 <- vcovHC(reg4.4, type = "HC1")
reg4.4 <- coeftest(reg4.4, vcov = se4.4)
reg4.4


# THIS ONE IS MISSING A COEFFICIENT
reg5.4 <- lm(ret_fd1 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona3)
se5.4 <- vcovHC(reg5.4, type = "HC1")
reg5.4 <- coeftest(reg5.4, vcov = se5.4)

reg6.4 <- lm(ret_fd1 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona4)
se6.4 <- vcovHC(reg6.4, type = "HC1")
reg6.4 <- coeftest(reg6.4, vcov = se6.4)

reg7.4 <- lm(ret_fd1 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot1)
se7.4 <- vcovHC(reg7.4, type = "HC1")
reg7.4 <- coeftest(reg7.4, vcov = se7.4)

reg8.4 <- lm(ret_fd1 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot2)
se8.4 <- vcovHC(reg8.4, type = "HC1")
reg8.4 <- coeftest(reg8.4, vcov = se8.4)

reg9.4 <- lm(ret_fd1 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot3)
se9.4 <- vcovHC(reg9.4, type = "HC1")
reg9.4 <- coeftest(reg9.4, vcov = se9.4)

# I report a transposed version of this table (transposed by chatGPT)
# set type to "text" so it's easily displayed, will change back to latex
# stargazer can't handle more than 7 models so I took out the last 2 for now
stargazer(reg1.4, reg2.4, reg3.4, reg4.4, reg5.4, reg6.4, reg7.4,
          se = list(se1.4, se2.4, se3.4, se4.4, se5.4, se6.4, se7.4),
          type = "text")

#-------------------------------------------------------------------------------
#
# returns 10 day post-headline (with confidence) 
#
#-------------------------------------------------------------------------------
reg1.5 <- lm(ret_fd10 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = base_blanks)
se1.5 <- vcovHC(reg1.5, type = "HC1")
reg1.5 <- coeftest(reg1.5, vcov = se1.5)

reg2.5 <- lm(ret_fd10 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = base_json)
se2.5 <- vcovHC(reg2.5, type = "HC1")
reg2.5 <- coeftest(reg2.5, vcov = se2.5)

reg3.5 <- lm(ret_fd10 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona1)
se3.5 <- vcovHC(reg3.5, type = "HC1")
reg3.5 <- coeftest(reg3.5, vcov = se3.5)

# ALSO MISSING
reg4.5 <- lm(ret_fd10 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona2)
se4.5 <- vcovHC(reg4.5, type = "HC1")
reg4.5 <- coeftest(reg4.5, vcov = se4.5)

# ALSO MISSING
reg5.5 <- lm(ret_fd10 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona3)
se5.5 <- vcovHC(reg5.5, type = "HC1")
reg5.5 <- coeftest(reg5.5, vcov = se5.5)

reg6.5 <- lm(ret_fd10 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = persona4)
se6.5 <- vcovHC(reg6.5, type = "HC1")
reg6.5 <- coeftest(reg6.5, vcov = se6.5)

reg7.5 <- lm(ret_fd10 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot1)
se7.5 <- vcovHC(reg7.5, type = "HC1")
reg7.5 <- coeftest(reg7.5, vcov = se7.5)

reg8.5 <- lm(ret_fd10 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot2)
se8.5 <- vcovHC(reg8.5, type = "HC1")
reg8.5 <- coeftest(reg8.5, vcov = se8.5)

reg9.5 <- lm(ret_fd10 ~ headline.type * confidence + ret_ld1 + ret_ld2 + ret_ld3 - 1,  data = cot3)
se9.5 <- vcovHC(reg9.5, type = "HC1")
reg9.5 <- coeftest(reg9.5, vcov = se9.5)

# I report a transposed version of this table (transposed by chatGPT)
# set type to "text" so it's easily displayed, will change back to latex
# stargazer can't handle more than 7 models so I took out the last 2 for now
stargazer(reg1.5, reg2.5, reg3.5, reg4.5, reg5.5, reg6.5, reg7.5,
          se = list(se1.5, se2.5, se3.5, se4.5, se5.5, se6.5, se7.5),
          type = "text")


print(sum(is.na(base_blanks$ret_fd1)))
