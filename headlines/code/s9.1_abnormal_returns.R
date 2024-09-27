library(dplyr)
library(ggplot2)
library(stargazer)
library(fixest)
library(sandwich)
library(broom)
library(glue)

# Reset environment 
rm(list = ls())
source(file.path("./code/produce_figures/ggplot_theme.r"))

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
  } else {
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
return_type <- "abnormal_FF3"
model_levels <- c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o")
model_labels <- c("GPT-3.5", "GPT-4o-mini", "GPT-4o")
model_map <- setNames(model_labels, model_levels)

# Placeholder lists for regression results and standard errors
reg_list <- list()
meta_data <- data.frame()

# Read, combine, and mutate data for all files
for (q in 1:length(questions)) {
  for (m in 1:length(model_levels)) {
    
    ############################################################################
    # Read in data for the current model and question                          #
    ############################################################################
    question = questions[q]
    model = model_levels[m]
    
    # Define the file path based on the current model and question
    path <- glue("./data/step6_common_sample/across_models/{return_type}/{model}/{question}/")
    
    # Read in data sets for various prompting strategies
    data_list <- lapply(c("base_blanks", "base_json", "cot1", "cot2", 
                          "cot3", "persona1", "persona2", "persona3", 
                          "persona4"), function(x) read.csv(glue("{path}{x}.csv")))
    
    dataset_names <- c("Base: Fill in Blank", "Base: JSON", 
                       "COT: Careful", "COT: Explanation", 
                       "COT: Step-by-step", "Persona: Economic Agent", 
                       "Persona: Finance Expert", "Persona: Economy Expert", 
                       "Persona: Successful Trader")
    
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
        
        temp_reg_list[[i]] <- reg
        
      } else {
        reg <- feols(sum_exret_1 ~
                       positive +
                       negative +
                       neutral +
                       positive.magnitude +
                       negative.magnitude +
                       neutral.magnitude - 1,
                     cluster = ~company_name + date,
                     data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = model_levels[m],
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
        
        temp_reg_list[[i]] <- reg
        
      } else {
        reg <- feols(sum_exret_5 ~
                       positive +
                       negative +
                       neutral +
                       positive.magnitude +
                       negative.magnitude +
                       neutral.magnitude - 1,
                     cluster = ~company_name + date,
                     data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = model_levels[m],
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
        
        temp_reg_list[[i]] <- reg
        
      } else {
        reg <- feols(sum_exret_10 ~
                       positive +
                       negative +
                       neutral +
                       positive.magnitude +
                       negative.magnitude +
                       neutral.magnitude - 1,
                     cluster = ~company_name + date,
                     data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = model_levels[m],
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
    
    # Run regressions in a loop
    for (i in 1:length(data_list)) {
      if (question != "q1") {
        reg <- feols(sum_exret_1 ~ increase +
                       decrease +
                       uncertain +
                       increase.confidence +
                       decrease.confidence +
                       uncertain.confidence - 1,
                     cluster = ~company_name + date,
                     data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
        
      } else {
        reg <- feols(sum_exret_1 ~
                       positive +
                       negative +
                       neutral +
                       positive.confidence +
                       negative.confidence +
                       neutral.confidence - 1,
                     cluster = ~company_name + date,
                     data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = model_levels[m],
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
    
    # Run regressions in a loop
    for (i in 1:length(data_list)) {
      if (question != "q1") {
        reg <- feols(sum_exret_5 ~ increase +
                       decrease +
                       uncertain +
                       increase.confidence +
                       decrease.confidence +
                       uncertain.confidence - 1,
                     cluster = ~company_name + date,
                     data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      } else {
        reg <- feols(sum_exret_5 ~
                       positive +
                       negative +
                       neutral +
                       positive.confidence +
                       negative.confidence +
                       neutral.confidence - 1,
                     cluster = ~company_name + date,
                     data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = model_levels[m],
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
    
    ############################################################################
    # Run regressions in a loop for confidence and 10-day                      #
    ############################################################################
    
    # Run regressions in a loop
    for (i in 1:length(data_list)) {
      if (question != "q1") {
        reg <- feols(sum_exret_10 ~ increase +
                       decrease +
                       uncertain +
                       increase.confidence +
                       decrease.confidence +
                       uncertain.confidence - 1,
                     cluster = ~company_name + date,
                     data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
        
      } else {
        reg <- feols(sum_exret_10 ~
                       positive +
                       negative +
                       neutral +
                       positive.confidence +
                       negative.confidence +
                       neutral.confidence - 1,
                     cluster = ~company_name + date,
                     data = data_list[[i]])
        
        temp_reg_list[[i]] <- reg
      }
      meta_data <- bind_rows(
        meta_data,
        data.frame(question = questions[q],
                   model = model_levels[m],
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
    
    cat(model, question, "\n")
  }
}

################################################################################
# Data to plot t-stats from regression results                                 #
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

plot_results$return_type <- return_type
write.csv(plot_results, glue("./data/step9_reg_results/{return_type}_returns_clustered.csv"))

################################################################################
# Ret 1, Ret 5, Ret 10 for Positive and Negative Returns (Prompt Index)        #
################################################################################
current_question = "q1"

arrange_gpt4o_data <- function(plot_data, coef_col, se_col) {
  plot_data %>%
    filter(model == "gpt-4o", question == current_question) %>%
    group_by(ret, mag_v_conf) %>%  # Group by time horizon and metric type
    mutate(tstat_value = !!sym(coef_col) / !!sym(se_col)) %>%
    arrange(tstat_value) %>%
    mutate(new_id = row_number()) %>%
    ungroup()
}

gpt4o_ordered_data_up <- arrange_gpt4o_data(plot_results, "up.coef", "up.se")
gpt4o_ordered_data_down <- arrange_gpt4o_data(plot_results, "down.coef", "down.se")

apply_gpt4o_order <- function(plot_data, ordered_data, coef_col, se_col) {
  plot_data %>%
    filter(question == current_question) %>%
    mutate(tstat_value = !!sym(coef_col) / !!sym(se_col)) %>%
    left_join(ordered_data %>% 
                select(group_id, ret, mag_v_conf, new_id), by = c("group_id", "ret", "mag_v_conf")) %>%
    select(-any_of("id")) %>%  # Remove all instances of 'id'
    rename(index_id = new_id) %>%
    mutate(model = as.factor(model),
           ret = factor(ret, levels = c("1-day", "5-day", "10-day")))
}

up_results_prompt_index <- apply_gpt4o_order(plot_results, gpt4o_ordered_data_up, "up.coef", "up.se")
down_results_prompt_index <- apply_gpt4o_order(plot_results, gpt4o_ordered_data_down, "down.coef", "down.se")

create_comparison_plot <- function(data, metric_label, title_prefix, alpha) {
  ggplot() +
    geom_hline(data = data, aes(yintercept = 0), color = "grey", size = 1) +
    geom_point(data = data %>%
                 filter(model == "gpt-3.5-turbo", mag_v_conf == metric_label), 
               aes(x = index_id, y = tstat_value, color = model_map["gpt-3.5-turbo"]), size = 3, shape = 16, alpha = alpha) +
    geom_point(data = data %>%
                 filter(model == "gpt-4o", mag_v_conf == metric_label), 
               aes(x = index_id, y = tstat_value, color = model_map["gpt-4o"]), size = 3, shape = 17) +
    geom_point(data = data %>%
                 filter(model == "gpt-4o-mini", mag_v_conf == metric_label), 
               aes(x = index_id, y = tstat_value, color = model_map["gpt-4o-mini"]), size = 3, shape = 15, alpha = alpha) +
    facet_grid(cols = vars(ret)) +
    scale_color_manual(values = my_colors, name = NULL, breaks = names(my_shapes)) +
    labs(y = "t-statistic",
         x = "Prompt Index (Sorted)") +
    theme.point
}

up_retcomp_prompt_magnitude <- create_comparison_plot(up_results_prompt_index, "magnitude", "`Up`", 0.7)
up_retcomp_prompt_confidence <- create_comparison_plot(up_results_prompt_index, "confidence", "`Up`", 0.7)
up_retcomp_prompt_magnitude
up_retcomp_prompt_confidence

down_retcomp_prompt_magnitude <- create_comparison_plot(down_results_prompt_index, "magnitude", "`Down`", 0.7)
down_retcomp_prompt_confidence <- create_comparison_plot(down_results_prompt_index, "confidence", "`Down`", 0.7)
down_retcomp_prompt_magnitude
down_retcomp_prompt_confidence

################################################################################
# Ret 1, Ret 5, Ret 10 for Positive and Negative Returns (Prompt+Model Index)  #
################################################################################

create_prompt_model_index <- function(plot_data, coef_col, se_col) {
  plot_data %>%
    filter(question == current_question) %>%
    mutate(tstat_value = !!sym(coef_col) / !!sym(se_col)) %>%
    group_by(ret, mag_v_conf) %>%  
    arrange(tstat_value) %>%  
    mutate(index_id = row_number()) %>%  
    ungroup() %>%
    mutate(model = as.factor(model),
           ret = factor(ret, levels = c("1-day", "5-day", "10-day")))  
}

up_results_prompt_model_index <- create_prompt_model_index(plot_results, "up.coef", "up.se")
down_results_prompt_model_index <- create_prompt_model_index(plot_results, "down.coef", "down.se")

up_retcomp_prompt_model_magnitude <- create_comparison_plot(up_results_prompt_model_index, "magnitude", "`Up` Positive", 0.7)
up_retcomp_prompt_model_confidence <- create_comparison_plot(up_results_prompt_model_index, "confidence", "`Up` Positive", 0.7)
up_retcomp_prompt_model_magnitude
up_retcomp_prompt_model_confidence

down_retcomp_prompt_model_magnitude <- create_comparison_plot(down_results_prompt_model_index, "magnitude", "`Down` Negative", 0.7)
down_retcomp_prompt_model_confidence <- create_comparison_plot(down_results_prompt_model_index, "confidence", "`Down` Negative", 0.7)
down_retcomp_prompt_model_magnitude
down_retcomp_prompt_model_confidence

