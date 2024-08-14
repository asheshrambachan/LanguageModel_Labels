library(dplyr)
library(ggplot2)
library(stargazer)
library(fixest)
library(modelsummary)

rm(list = ls())

# Define the question and the list of months
questions <- c("q1", "q2", "q3", "q4", "q5")
months <- c("jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "octfirst", "octsecond", "nov", "dec")
year = "19"
return_type = "cumulative"
models = c("gpt-3.5-turbo-0215", "gpt-4o-mini")

# Function to read and combine data for all months
read_and_combine <- function(file_name, months, question, model) {
  combined_df <- data.frame()  
  # Initialize an empty data frame to store combined data
  for (month in months) {
    file_path <- paste0("./data/step5_returns_merged/", 
                        return_type, "/", 
                        model, "/", 
                        question, "/",  
                        question, "_", month, "19/", 
                        file_name,
                        ".csv")
    month_df <- read.csv(file_path)
    # Filter out rows with empty headline.type
    month_df <- subset(month_df, headline.type != "")  
    # Combine data frames
    combined_df <- bind_rows(combined_df, month_df) 
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

# Placeholder lists for regression results and standard errors
reg_list <- list()
meta_data <- data.frame()

# Read, combine, and mutate data for all files
for (q in 1:length(questions)) {
  for (m in 1:length(models)) {
    question = questions[q]
    model = models[m]
    
    # Read, combine, and mutate data for all files
    combined_data <- lapply(file_names, function(file_name) {
      df <- read_and_combine(file_name, months, question, model)
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
    data_list <- list(base_blanks, 
                      base_json, 
                      persona1, 
                      persona2, 
                      persona3, 
                      persona4, 
                      cot1, 
                      cot2, 
                      cot3)
  
    if (question != "q1") {
      magnitude_labels <- c("Increase", "Decrease", "Uncertain", 
                            "Increase Magnitude", "Decrease Magnitude", 
                            "Uncertain Magnitude", "Ret LD1", 
                            "Ret LD2", "Ret LD3")
      confidence_labels <- c("Increase", "Decrease", "Uncertain", 
                             "Increase Confidence", "Decrease Confidence", 
                             "Uncertain Confidence", "Ret LD1", 
                             "Ret LD2", "Ret LD3")
    } else {
      magnitude_labels <- c("Positive", "Negative", "Neutral", 
                            "Positive Magnitude", "Negative Magnitude",
                            "Neutral Magnitude", "Ret LD1", 
                            "Ret LD2", "Ret LD3")
      confidence_labels <- c("Positive", "Negative", "Neutral", 
                             "Positive Confidence", "Negative Confidence", 
                             "Neutral Confidence", "Ret LD1", 
                             "Ret LD2", "Ret LD3")
    }
    
    temp_reg_list <- list()
  
    ############################################################################
    # Run regressions in a loop for magnitude and 1-day                        #
    ############################################################################
    for (i in 1:length(data_list)) {
      if (question != "q1") {
        reg <-  feols(ret_fd1 ~ 
                        increase +
                        decrease +
                        uncertain + 
                        increase.magnitude +
                        decrease.magnitude +
                        uncertain.magnitude +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      else {
        reg <-  feols(ret_fd1 ~ 
                        positive +
                        negative +
                        neutral + 
                        positive.magnitude +
                        negative.magnitude +
                        neutral.magnitude +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = models[m],
                   prompt = file_names[i], 
                   mag_v_conf = "magnitude", 
                   ret = "1-day")
      )
    }
    reg_list <- c(reg_list, temp_reg_list)
  
    ############################################################################
    # Run regressions in a loop for magnitude and 5-day                        #
    ############################################################################
    for (i in 1:length(data_list)) {
      if (question != "q1") {
        reg <-  feols(ret_fd5 ~ 
                        increase +
                        decrease +
                        uncertain + 
                        increase.magnitude +
                        decrease.magnitude +
                        uncertain.magnitude +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      else {
        reg <-  feols(ret_fd5 ~ 
                        positive +
                        negative +
                        neutral + 
                        positive.magnitude +
                        negative.magnitude +
                        neutral.magnitude +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = models[m],
                   prompt = file_names[i], 
                   mag_v_conf = "magnitude", 
                   ret = "5-day")
      )
    }
    reg_list <- c(reg_list, temp_reg_list)
  
    ############################################################################
    # Run regressions in a loop for magnitude and 10-day                       #
    ############################################################################
    for (i in 1:length(data_list)) {
      if (question != "q1") {
        reg <-  feols(ret_fd10 ~ 
                        increase +
                        decrease +
                        uncertain + 
                        increase.magnitude +
                        decrease.magnitude +
                        uncertain.magnitude +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      else {
        reg <-  feols(ret_fd10 ~ 
                        positive +
                        negative +
                        neutral + 
                        positive.magnitude +
                        negative.magnitude +
                        neutral.magnitude +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = models[m],
                   prompt = file_names[i], 
                   mag_v_conf = "magnitude", 
                   ret = "10-day")
      )
    }
    reg_list <- c(reg_list, temp_reg_list)
  
    ############################################################################
    # Run regressions in a loop for confidence and 1-day                       #
    ############################################################################
    for (i in 1:length(data_list)) {
      if (question != "q1") {
        reg <-  feols(ret_fd1 ~ 
                        increase +
                        decrease +
                        uncertain + 
                        increase.confidence +
                        decrease.confidence +
                        uncertain.confidence +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      else {
        reg <-  feols(ret_fd1 ~ 
                        positive +
                        negative +
                        neutral + 
                        positive.confidence +
                        negative.confidence +
                        neutral.confidence +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = models[m],
                   prompt = file_names[i], 
                   mag_v_conf = "confidence", 
                   ret = "1-day")
      )
    }
    reg_list <- c(reg_list, temp_reg_list)
  
    ############################################################################
    # Run regressions in a loop for confidence and 5-day                       #
    ############################################################################
    for (i in 1:length(data_list)) {
      if (question != "q1") {
        reg <-  feols(ret_fd5 ~ 
                        increase +
                        decrease +
                        uncertain + 
                        increase.confidence +
                        decrease.confidence +
                        uncertain.confidence +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      else {
        reg <-  feols(ret_fd5 ~ 
                        positive +
                        negative +
                        neutral + 
                        positive.confidence +
                        negative.confidence +
                        neutral.confidence +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = models[m],
                   prompt = file_names[i], 
                   mag_v_conf = "confidence", 
                   ret = "5-day")
      )
    }
    reg_list <- c(reg_list, temp_reg_list)
  
    ##############################################################################
    # Run regressions in a loop for confidence and 10-day                        #
    ##############################################################################
    for (i in 1:length(data_list)) {
      if (question != "q1") {
        reg <-  feols(ret_fd10 ~ 
                        increase +
                        decrease +
                        uncertain + 
                        increase.confidence +
                        decrease.confidence +
                        uncertain.confidence +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      else {
        reg <-  feols(ret_fd10 ~ 
                        positive +
                        negative +
                        neutral + 
                        positive.confidence +
                        negative.confidence +
                        neutral.confidence +
                        ret_ld1 +
                        ret_ld2 +
                        ret_ld3 - 1,,
                      cluster = ~company_name + date,
                      data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = models[m],
                   prompt = file_names[i], 
                   mag_v_conf = "confidence", 
                   ret = "10-day")
      )
    }
    reg_list <- c(reg_list, temp_reg_list)
  }
}
################################################################################
#                        !!! END OF GIANT FOR LOOP !!!                         # 
################################################################################


################################################################################
# Plotting results                                                             #
################################################################################
plot_results <- data.frame()
n = length(reg_list)

for (i in 1:n) {
  reg <- reg_list[[i]]
  se < - se_list[[i]]
  if (meta_data$question[i] != "q1") {
    temp <- data.frame(question = meta_data$question[i],
                       model = meta_data$model[[i]],
                       prompt = meta_data$prompt[i], 
                       mag_v_conf = meta_data$mag_v_conf[i],
                       ret = meta_data$ret[i],
                       up.coef = reg$coefficients[names(reg$coefficients) == "increase"],
                       down.coef = reg$coefficients[names(reg$coefficients) == "decrease"], 
                       up.se = reg$se[names(reg$se) == "increase"], 
                       down.se = reg$se[names(reg$se) == "decrease"])
  } else {
    temp <- data.frame(question = meta_data$question[i],
                       model = meta_data$model[[i]],
                       prompt = meta_data$prompt[i], 
                       mag_v_conf = meta_data$mag_v_conf[i],
                       ret = meta_data$ret[i],
                       up.coef = reg$coefficients[names(reg$coefficients) == "positive"],
                       down.coef = reg$coefficients[names(reg$coefficients) == "negative"], 
                       up.se = reg$se[names(reg$se) == "positive"], 
                       down.se = reg$se[names(reg$se) == "negative"])
  }
  plot_results <- bind_rows(plot_results, temp)
}

################################################################################
# Plot results for Ret 1 Positive                                              #
################################################################################
plot_results_pos_ret1 <- plot_results %>% 
  filter(ret == "1-day") %>%
  mutate(
    up.tstat = up.coef/up.se
  ) %>%
  arrange(up.tstat) %>%
  mutate(
    id = 1:n() 
  )

# Positive + q1 
pos_ret1_3 <- ggplot() + 
  geom_point(data = plot_results_pos_ret1 %>% filter(
    question == "q1" &
      model == "gpt-3.5-turbo-0215" &
      mag_v_conf == "magnitude" &
      prompt == "base_json"),
    aes(x = id, y = up.tstat, color = "gpt-3.5-turbo-0215, base"), 
    size = 4, shape = 17) +
  
  geom_point(data = plot_results_pos_ret1 %>% filter(
    question == "q1" &
      model == "gpt-3.5-turbo-0215" &
      prompt != "base_json"),
    aes(x = id, y = up.tstat, color = "gpt-3.5-turbo-0215, base"), size = 2, alpha = 0.6) +
  
  geom_point(data = plot_results_pos_ret1 %>% filter(
    question == "q1" &
      model == "gpt-4o-mini" &
      mag_v_conf == "magnitude" &
      prompt == "base_json"),
    aes(x = id, y = up.tstat, color = "gpt-4o-mini, base"), 
    size = 4, shape = 17) +
  
  geom_point(data = plot_results_pos_ret1 %>% filter(
    question == "q1" &
      model == "gpt-4o-mini" &
      prompt != "base_json"),
    aes(x = id, y = up.tstat, color = "gpt-4o-mini, base"), size = 2, alpha = 0.6) +
  
  xlim(1, 180) + ylim(-5, 5) +
  labs(y = "t-statistic", color = "Model") +  # Adding a label for the legend
  scale_color_manual(values = c("gpt-3.5-turbo-0215, base" = "#D81B60", "gpt-4o-mini, base" = "#0072B2")) + 
  theme_bw() +
  theme(axis.title.x = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

pos_ret1_3
ggsave(filename = "temp_figs/pos_ret1_q1.jpeg", units = "in", width = 8, height = 6)

#####################################################
# Compare Ret 1, Ret 5, Ret 10 for positive Returns #
#####################################################
pos_results <-
bind_rows(
  plot_results_pos_ret1 %>% mutate(ret = "1 Day"),
  plot_results %>% filter(ret == "5-day") %>%
    mutate(up.tstat = up.coef/up.se) %>%
    arrange(up.tstat) %>%
    mutate(id = 1:n(),
           ret = "5 Day"), 
  plot_results %>% filter(ret == "10-day") %>%
    mutate(up.tstat = up.coef/up.se) %>%
    arrange(up.tstat) %>%
    mutate(id = 1:n(),
           ret = "10 Day"), 
)

pos_results <- pos_results %>%
  mutate(model = as.factor(model)) %>%
  mutate(ret = factor(ret, levels = c("1 Day", "5 Day", "10 Day"))) %>%
  filter(question == "q5")

pos_retcomp <- ggplot(data = pos_results) + 
geom_point(aes(x = id, y = up.tstat,  color = model), 
           size = 2, alpha = 0.5) + 
geom_hline(aes(yintercept = -1.96), linetype = "dashed", color = "black") + 
geom_hline(aes(yintercept = 1.96), linetype = "dashed", color = "black") + 
facet_grid(cols = vars(ret)) + 
scale_color_manual(values = c("gpt-4o-mini" = "#0072B2", "gpt-3.5-turbo-0215" = "#D81B60")) +
xlim(1, 180) + ylim(-5, 5) + 
labs(y = "t-statistic") +
theme_bw() + theme(axis.title.x=element_blank(),
                   axis.text.x=element_blank(),
                   axis.ticks.x=element_blank())

pos_retcomp
ggsave(filename = "temp_figs/t_stat_comparison/pos_ret_q5.jpeg", units = "in", width = 7, height = 4)

################################################################################
# Plot results for Ret 1 Negative                                              #
################################################################################
plot_results_neg_ret1 <- plot_results %>% 
  filter(ret == "1-day") %>%
  mutate(
    down.tstat = down.coef/down.se
  ) %>%
  arrange(down.tstat) %>%
  mutate(
    id = 1:n() 
  )

# Negative + q1 
neg_ret1_3 <- ggplot() + 
  geom_point(data = plot_results_neg_ret1 %>% filter(
    question == "q1" &
      model == "gpt-3.5-turbo-0215" &
      prompt != "base_json"),
    aes(x = id, y = down.tstat), color = "#D81B60", size = 2, alpha = 0.6) +
  
  geom_point(data = plot_results_neg_ret1 %>% filter(
    question == "q1" &
      model == "gpt-3.5-turbo-0215" &
      mag_v_conf == "magnitude" &
      prompt == "base_json"),
    aes(x = id, y = down.tstat), 
    size = 4, shape = 17, color = "#D81B60") +
  
  geom_point(data = plot_results_neg_ret1 %>% filter(
    question == "q1" &
      model == "gpt-4o-mini" &
      prompt != "base_json"),
    aes(x = id, y = down.tstat), color = "#0072B2", size = 2, alpha = 0.6) +
  
  geom_point(data = plot_results_neg_ret1 %>% filter(
    question == "q1" &
      model == "gpt-4o-mini" &
      mag_v_conf == "magnitude" &
      prompt == "base_json"),
    aes(x = id, y = down.tstat), 
    size = 4, shape = 17, color = "#0072B2") +
  
  xlim(1, 180) + ylim(-5, 5) +
  labs(y = "t-statistic") + 
  theme_bw() +
  theme(axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank())

neg_ret1_3

#####################################################
# Compare Ret 1, Ret 5, Ret 10 for positive Returns #
#####################################################
neg_results <-
  bind_rows(
    plot_results_neg_ret1 %>% mutate(ret = "1 Day"),
    plot_results %>% filter(ret == "5-day") %>%
      mutate(down.tstat = down.coef/down.se) %>%
      arrange(down.tstat) %>%
      mutate(id = 1:n(),
             ret = "5 Day"), 
    plot_results %>% filter(ret == "10-day") %>%
      mutate(down.tstat = down.coef/down.se) %>%
      arrange(down.tstat) %>%
      mutate(id = 1:n(),
             ret = "10 Day"), 
  )

neg_results <- neg_results %>%
  mutate(model = as.factor(model)) %>%
  mutate(ret = factor(ret, levels = c("1 Day", "5 Day", "10 Day"))) %>%
  filter(question == "q4")

neg_retcomp <- ggplot(data = neg_results) + 
  geom_point(aes(x = id, y = down.tstat,  color = model), 
             size = 2, alpha = 0.5) + 
  geom_hline(aes(yintercept = -1.96), linetype = "dashed", color = "black") + 
  geom_hline(aes(yintercept = 1.96), linetype = "dashed", color = "black") + 
  facet_grid(cols = vars(ret)) + 
  scale_color_manual(values = c("gpt-4o-mini" = "#0072B2", "gpt-3.5-turbo-0215" = "#D81B60")) +
  xlim(1, 180) + ylim(-12, 5) + 
  labs(y = "t-statistic") +
  theme_bw() + theme(axis.title.x=element_blank(),
                     axis.text.x=element_blank(),
                     axis.ticks.x=element_blank())

neg_retcomp
ggsave(filename = "temp_figs/t_stat_comparison/neg_ret_q4.jpeg", units = "in", width = 7, height = 4)
