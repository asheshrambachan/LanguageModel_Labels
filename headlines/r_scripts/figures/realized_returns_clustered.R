library(dplyr)
library(ggplot2)
library(stargazer)
library(fixest)
library(modelsummary)

################################################################################
# Generate the ordered t-stat figure for each model/question combo.            #
################################################################################

################################################################################
# Define helper functions                                                      #
################################################################################

# Reset environment 
rm(list = ls())

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

################################################################################
# Iterate over all questions and models to process data and create summaries   #
################################################################################

# List of file names
file_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3",
                "persona1", "persona2", "persona3", "persona4")

# Define the questions list, return type, and list of models we are comparing
questions <- c("q1", "q2", "q3", "q4", "q5")
return_type = "realized"
models = c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o")

# Placeholder lists for regression results and standard errors
reg_list <- list()
meta_data <- data.frame()


# Read, combine, and mutate data for all files
for (q in 1:length(questions)) {
  for (m in 1:length(models)) {
    
    ############################################################################
    # Read in data for the current model and question                          #
    ############################################################################
    
    question = questions[q]
    model = models[m]
    
    # Print the current model and question being processed
    cat(model, question, "\n")
    
    # Define the file path based on the current model and question
    path <- glue("../../data/step6_common_sample/across_models/{return_type}/{model}/{question}/")
    
    # Read in data sets for various prompting strategies
    data_list <- lapply(c("base_blanks", "base_json", "cot1", "cot2", 
                          "cot3", "persona1", "persona2", "persona3", 
                          "persona4"), 
                        function(x) read.csv(glue("{path}{x}.csv")))
    
    dataset_names <- c("Base: Fill in Blank", "Base: JSON", 
                       "COT: Careful", "COT: Explanation", 
                       "COT: Step-by-step", "Persona: Economic Agent", 
                       "Persona: Finance Expert", "Persona: Economy Expert", 
                       "Persona: Successful Trader")
    
    # Confirm that data has been read successfully
    print("read data")
    
    data_list <- lapply(data_list, mutate_data)
    
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
    
    # modelsummary(reg_list, 
    #              coef_rename = magnitude_labels,
    #              gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE", 
    #              stars = TRUE)
    
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
    
    # modelsummary(reg_list, 
    #              coef_rename = magnitude_labels,
    #              gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE", 
    #              stars = TRUE)
    
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
    
    # modelsummary(reg_list, 
    #              coef_rename = magnitude_labels,
    #              gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE", 
    #              stars = TRUE)
    
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
    
    # modelsummary(reg_list, 
    #              coef_rename = confidence_labels,
    #              gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE", 
    #              stars = TRUE)

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
    
    # modelsummary(reg_list, 
    #              coef_rename = confidence_labels,
    #              gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE", 
    #              stars = TRUE)

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
    
    # modelsummary(reg_list, 
    #              coef_rename = confidence_labels,
    #              gof_omit = "AIC|BIC|Std.Errors|R2 Adj.|RMSE", 
    #              stars = TRUE)

  }
}
################################################################################
#                        !!! END OF GIANT FOR LOOP !!!                         #
################################################################################

################################################################################
# Plotting t-stats from regression results                                     #
################################################################################

# Create empty data frame for storing plot information
plot_results <- data.frame()
n = length(reg_list)

# Iterate over all the models and extract coefficient info for plotting
for (i in 1:n) {
  reg <- reg_list[[i]]
  
  # Create a group_id based on the combination of metadata
  group_id <- paste(meta_data$question[i], 
                    meta_data$mag_v_conf[i], 
                    meta_data$ret[i], 
                    meta_data$prompt[i], 
                    sep = "_")
  
  if (meta_data$question[i] != "q1") {
    temp <- data.frame(question = meta_data$question[i],
                       model = meta_data$model[[i]],
                       prompt = meta_data$prompt[i],
                       mag_v_conf = meta_data$mag_v_conf[i],
                       ret = meta_data$ret[i],
                       up.coef = reg$coefficients[names(reg$coefficients) 
                                                  == "increase"],
                       down.coef = reg$coefficients[names(reg$coefficients) 
                                                    == "decrease"],
                       up.se = reg$se[names(reg$se) == "increase"],
                       down.se = reg$se[names(reg$se) == "decrease"])
  } else {
    temp <- data.frame(question = meta_data$question[i],
                       model = meta_data$model[[i]],
                       prompt = meta_data$prompt[i],
                       mag_v_conf = meta_data$mag_v_conf[i],
                       ret = meta_data$ret[i],
                       up.coef = reg$coefficients[names(reg$coefficients) 
                                                  == "positive"],
                       down.coef = reg$coefficients[names(reg$coefficients) 
                                                    == "negative"],
                       up.se = reg$se[names(reg$se) == "positive"],
                       down.se = reg$se[names(reg$se) == "negative"])
  }
  temp$group_id = group_id
  
  # Append the temp data frame to the plot_results data frame
  plot_results <- bind_rows(plot_results, temp)
}

plot_results <- plot_results %>%
  group_by(group_id) %>%
  mutate(id = cur_group_id()) %>%
  ungroup()

################################################################################
# Plot results for Positive/Increase 1-day post headline                       #
################################################################################

# Set the current question. We will filter by question in these plots for now. 
# Can use the plot_results df instead of plot_results_question to not filter. 
current_question = "q1"

# Ensure that group_id is correctly calculated
plot_results_question <- plot_results %>%
  group_by(group_id) %>%
  mutate(id = cur_group_id()) %>%
  ungroup()

# Arrange the gpt-4o group by up.tstat and assign sequential IDs
gpt4o_arranged_up <- plot_results_question %>%
  filter(model == "gpt-4o" & ret == "1-day" & question == current_question) %>%
  mutate(up.tstat = up.coef/up.se) %>%
  arrange(up.tstat) %>%
  mutate(new_id = row_number())  # Renaming id to new_id to avoid confusion

# Filter the data for plotting to just results for 1-day post headline
# Use the IDs ordered by GPT-4o from above
plot_results_pos_ret1 <- plot_results_question %>%
  filter(ret == "1-day", question == current_question) %>%
  mutate(up.tstat = up.coef/up.se) %>%
  left_join(gpt4o_arranged_up %>% select(group_id, new_id), 
            by = "group_id") %>%
  arrange(new_id)

# Check and remove any existing id column before renaming new_id
if ("id" %in% colnames(plot_results_pos_ret1)) {
  plot_results_pos_ret1 <- plot_results_pos_ret1 %>%
    select(-id)
}

# Rename new_id back to id for plotting purposes
plot_results_pos_ret1 <- plot_results_pos_ret1 %>%
  rename(id = new_id)

ggplot() +
  geom_point(data = plot_results_pos_ret1 %>% 
               filter(model == "gpt-3.5-turbo",
                      prompt == "base_json",
                      mag_v_conf == "magnitude"),
             aes(x = id, y = up.tstat, color = "gpt-3.5-turbo, base"),
             size = 4, shape = 17) +
  geom_point(data = plot_results_pos_ret1 %>% 
               filter(model == "gpt-4o-mini",
                      prompt == "base_json",
                      mag_v_conf == "magnitude"),
             aes(x = id, y = up.tstat, color = "gpt-4o-mini, base"),
             size = 4, shape = 17) +
  geom_point(data = plot_results_pos_ret1 %>% 
               filter(model == "gpt-4o",
                      prompt == "base_json",
                      mag_v_conf == "magnitude"),
             aes(x = id, y = up.tstat, color = "gpt-4o, base"),
             size = 4, shape = 17) +
  
  geom_point(data = plot_results_pos_ret1 %>%
               filter(model == "gpt-3.5-turbo"),
             aes(x = id, y = up.tstat, color = "gpt-3.5-turbo, base"),
             size = 2, alpha = 0.5) +
  geom_point(data = plot_results_pos_ret1 %>%
               filter(model == "gpt-4o-mini"),
             aes(x = id, y = up.tstat, color = "gpt-4o-mini, base"),
             size = 2, alpha = 0.5) +
  geom_point(data = plot_results_pos_ret1 %>%
               filter(model == "gpt-4o"),
             aes(x = id, y = up.tstat, color = "gpt-4o, base"),
             size = 2) +
  labs(y = "t-statistic", color = "Model",
       title = "Positive/Up T-Statistic for Realized Returns \n(Clustered SEs by Date and Firm)") +
  
  scale_color_manual(values = c("gpt-3.5-turbo, base" = "#D81B60", 
                                "gpt-4o-mini, base" = "#0072B2",  
                                "gpt-4o, base" = "green4")) +
  theme_bw() +
  theme(axis.title.x = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

################################################################################
# Compare Ret 1, Ret 5, Ret 10 for positive returns                            #
################################################################################

# Arrange GPT-4o separately for each time horizon and assign sequential IDs
arranged_data <- list()

# Loop over each time group
for (horizon in c("1-day", "5-day", "10-day")) {
  arranged <- plot_results %>%
    filter(model == "gpt-4o" & ret == horizon & 
             question == current_question) %>%
    mutate(up.tstat = up.coef/up.se) %>%
    arrange(up.tstat) %>%
    mutate(new_id = row_number(), ret = horizon)  # Assign IDs based on order
  
  arranged_data[[horizon]] <- arranged
}

# Combine the arranged data into one data frame
gpt4o_arranged_up <- bind_rows(arranged_data)

# Apply the GPT-4o order to each time horizon and ensure unique id column
pos_results <- bind_rows(
  plot_results %>%
    filter(ret == "1-day", question == current_question) %>%
    mutate(up.tstat = up.coef/up.se) %>%
    left_join(gpt4o_arranged_up %>% filter(ret == "1-day") %>% 
                select(group_id, new_id), by = "group_id") %>%
    mutate(ret = "1 Day"),
  
  plot_results %>%
    filter(ret == "5-day", question == current_question) %>%
    mutate(up.tstat = up.coef/up.se) %>%
    left_join(gpt4o_arranged_up %>% filter(ret == "5-day") %>% 
                select(group_id, new_id), by = "group_id") %>%
    mutate(ret = "5 Day"),
  
  plot_results %>%
    filter(ret == "10-day", question == current_question) %>%
    mutate(up.tstat = up.coef/up.se) %>%
    left_join(gpt4o_arranged_up %>% filter(ret == "10-day") %>% 
                select(group_id, new_id), by = "group_id") %>%
    mutate(ret = "10 Day")
)

# Remove all instances of 'id' before renaming 'new_id' to 'id'
pos_results <- pos_results %>%
  select(-any_of("id")) %>%
  rename(id = new_id) %>%
  mutate(model = as.factor(model),
         ret = factor(ret, levels = c("1 Day", "5 Day", "10 Day")))

# Create the returns comparison plot
pos_retcomp <- ggplot() +
  geom_point(data = pos_results %>%
               filter(model=="gpt-4o"), 
             aes(x = id, y = up.tstat, color = model), size = 2) +
  geom_point(data = pos_results, aes(x = id, y = up.tstat, color = model), 
             size = 2, alpha = 0.5) +
  geom_hline(data = pos_results, aes(yintercept = -1.96), 
             linetype = "dashed", color = "black") +
  geom_hline(data = pos_results, aes(yintercept = 1.96), 
             linetype = "dashed", color = "black") +
  facet_grid(cols = vars(ret)) +
  scale_color_manual(values = c("gpt-4o-mini" = "#0072B2", 
                                "gpt-3.5-turbo" = "#D81B60", 
                                "gpt-4o" = "green4")) +
  labs(y = "t-statistic",
       title = glue("Up/Positive T-statistic Comparison by Returns Horizon for 
                    Realized Returns")) +
  theme_bw() +
  theme(axis.title.x = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

pos_retcomp

################################################################################
# Plot results for Negative/Decrease 1-day post headline                       #
################################################################################

# Arrange the gpt-4o group by down.tstat and assign sequential IDs
gpt4o_arranged_down <- plot_results_question %>%
  filter(model == "gpt-4o" & ret == "1-day" & question == current_question) %>%
  mutate(down.tstat = down.coef/down.se) %>%
  arrange(down.tstat) %>%
  mutate(new_id = row_number())  # Renaming id to new_id to avoid confusion

# Filter the data for plotting to just results for 1-day post headline
# Use the IDs ordered by GPT-4o from above
plot_results_neg_ret1 <- plot_results_question %>%
  filter(ret == "1-day", question == current_question) %>%
  mutate(down.tstat = down.coef/down.se) %>%
  left_join(gpt4o_arranged_down %>% select(group_id, new_id), 
            by = "group_id") %>%
  arrange(new_id)

# Check and remove any existing id column before renaming new_id
if ("id" %in% colnames(plot_results_neg_ret1)) {
  plot_results_neg_ret1 <- plot_results_neg_ret1 %>%
    select(-id)
}

# Rename new_id back to id for plotting purposes
plot_results_neg_ret1 <- plot_results_neg_ret1 %>%
  rename(id = new_id)

ggplot() +
  geom_point(data = plot_results_neg_ret1 %>% 
               filter(model == "gpt-3.5-turbo",
                      prompt == "base_json",
                      mag_v_conf == "magnitude"),
             aes(x = id, y = down.tstat, color = "gpt-3.5-turbo, base"),
             size = 4, shape = 17) +
  geom_point(data = plot_results_neg_ret1 %>% 
               filter(model == "gpt-4o-mini",
                      prompt == "base_json",
                      mag_v_conf == "magnitude"),
             aes(x = id, y = down.tstat, color = "gpt-4o-mini, base"),
             size = 4, shape = 17) +
  geom_point(data = plot_results_neg_ret1 %>% 
               filter(model == "gpt-4o",
                      prompt == "base_json",
                      mag_v_conf == "magnitude"),
             aes(x = id, y = down.tstat, color = "gpt-4o, base"),
             size = 4, shape = 17) +
  
  geom_point(data = plot_results_neg_ret1 %>%
               filter(model == "gpt-3.5-turbo"),
             aes(x = id, y = down.tstat, color = "gpt-3.5-turbo, base"),
             size = 2, alpha = 0.5) +
  geom_point(data = plot_results_neg_ret1 %>%
               filter(model == "gpt-4o-mini"),
             aes(x = id, y = down.tstat, color = "gpt-4o-mini, base"),
             size = 2, alpha = 0.5) +
  geom_point(data = plot_results_neg_ret1 %>%
               filter(model == "gpt-4o"),
             aes(x = id, y = down.tstat, color = "gpt-4o, base"),
             size = 2) +
  labs(y = "t-statistic", color = "Model",
       title= "Negative/Down T-Statistic for Realized Returns \n(Clustered SEs by Date and Firm)") +
  
  scale_color_manual(values = c("gpt-3.5-turbo, base" = "#D81B60", 
                                "gpt-4o-mini, base" = "#0072B2",  
                                "gpt-4o, base" = "green4")) +
  theme_bw() +
  theme(axis.title.x = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

################################################################################
# Compare Ret 1, Ret 5, Ret 10 for negative returns                            #
################################################################################

# Arrange GPT-4o separately for each time horizon and assign sequential IDs
arranged_data <- list()

# Loop over each time group
for (horizon in c("1-day", "5-day", "10-day")) {
  arranged <- plot_results %>%
    filter(model == "gpt-4o" & ret == horizon & 
             question == current_question) %>%
    mutate(down.tstat = down.coef/down.se) %>%
    arrange(down.tstat) %>%
    mutate(new_id = row_number(), ret = horizon)  # Assign IDs based on order
  
  arranged_data[[horizon]] <- arranged
}

# Combine the arranged data into one data frame
gpt4o_arranged_down <- bind_rows(arranged_data)

# Apply the GPT-4o order to each time horizon and ensure unique id column
neg_results <- bind_rows(
  plot_results %>%
    filter(ret == "1-day", question == current_question) %>%
    mutate(down.tstat = down.coef/down.se) %>%
    left_join(gpt4o_arranged_down %>% filter(ret == "1-day") %>% 
                select(group_id, new_id), by = "group_id") %>%
    mutate(ret = "1 Day"),
  
  plot_results %>%
    filter(ret == "5-day", question == current_question) %>%
    mutate(down.tstat = down.coef/down.se) %>%
    left_join(gpt4o_arranged_down %>% filter(ret == "5-day") %>% 
                select(group_id, new_id), by = "group_id") %>%
    mutate(ret = "5 Day"),
  
  plot_results %>%
    filter(ret == "10-day", question == current_question) %>%
    mutate(down.tstat = down.coef/down.se) %>%
    left_join(gpt4o_arranged_down %>% filter(ret == "10-day") %>% 
                select(group_id, new_id), by = "group_id") %>%
    mutate(ret = "10 Day")
)

# Remove all instances of 'id' before renaming 'new_id' to 'id'
neg_results <- neg_results %>%
  select(-any_of("id")) %>%
  rename(id = new_id) %>%
  mutate(model = as.factor(model),
         ret = factor(ret, levels = c("1 Day", "5 Day", "10 Day")))

# Create the returns comparison plot
neg_retcomp <- ggplot() +
  geom_point(data = neg_results %>%
               filter(model=="gpt-4o"), 
             aes(x = id, y = down.tstat, color = model), size = 2) +
  geom_point(data = neg_results, aes(x = id, y = down.tstat, color = model), 
             size = 2, alpha = 0.5) +
  geom_hline(data = neg_results, aes(yintercept = -1.96), 
             linetype = "dashed", color = "black") +
  geom_hline(data = neg_results, aes(yintercept = 1.96), 
             linetype = "dashed", color = "black") +
  facet_grid(cols = vars(ret)) +
  scale_color_manual(values = c("gpt-4o-mini" = "#0072B2", 
                                "gpt-3.5-turbo" = "#D81B60", 
                                "gpt-4o" = "green4")) +
  labs(y = "t-statistic",
       title = glue("`Down` T-statistic Comparison by Returns Horizon for 
                    Realized Returns Under {return_type}")) +
  theme_bw() +
  theme(axis.title.x = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

neg_retcomp
