library(tidyr)
library(dplyr)
library(ggplot2)
library(stargazer)
library(gridExtra)
library(lmtest)

# reset workspace
rm(list = ls())

#-------------------------------------------------------------------------------
# Function to calculate statistics for each dataset
convert_headline_type <- function(df) {
  df %>%
    mutate(
      headline.type.common = case_when(
        headline.type %in% c("positive", "increase") ~ "up",
        headline.type %in% c("negative", "decrease") ~ "down",
        headline.type %in% c("neutral", "uncertain") ~ "neutral",
        TRUE ~ NA_character_  # Just in case there are other values, you can handle them here
      )
    )
}

calculate_stats <- function(df) {
  # Calculate mean, median, and standard deviation of confidence and magnitude
  stats <- df %>%
    summarize(
      mean_conf = mean(confidence, na.rm = TRUE),
      median_conf = median(confidence, na.rm = TRUE),
      sd_conf = sd(confidence, na.rm = TRUE),
      mean_mag = mean(magnitude, na.rm = TRUE),
      median_mag = median(magnitude, na.rm = TRUE),
      sd_mag = sd(magnitude, na.rm = TRUE)
    )
  
  counts <- df %>%
    summarize(
      up = sum(headline.type.common == "up", na.rm = TRUE),
      down = sum(headline.type.common == "down", na.rm = TRUE),
      neutral = sum(headline.type.common == "neutral", na.rm = TRUE)
    )
  
  # Combine statistics and frequencies into a single data frame
  result <- cbind(stats, counts)
  return(result)
}

#------------------------------------------------------------------------------

freq_list <- list()
conf_list <- list()
conf_split_list <- list()
mag_list <- list()
mag_split_list <- list()

questions <- c("q1", "q2", "q3", "q4", "q5")
models <- c("gpt-3.5-turbo", "gpt-4o-mini")
return_type = "cumulative"

for (question in questions) {
  for (model in models) {
    
    print(model)
    print(question)
    
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
    
    print("read data")
    
    #-------------------------------------------------------------------------------
    # List to store results
    results_summary_list <- list()
    results_list <- list()
    
    # Apply the function to each data set and store results
    datasets <- list(base_blanks, base_json, cot1, cot2, cot3, 
                     persona1, persona2, persona3, persona4)
    dataset_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", 
                     "persona1", "persona2", "persona3", "persona4")
    
    datasets <- lapply(datasets, convert_headline_type)
    
    for (i in 1:length(datasets)) {
      results_summary_list[[dataset_names[i]]] <- calculate_stats(datasets[[i]])
      results_list[[dataset_names[i]]] <- datasets[[i]]
    }
    
    # Combine all results into a single data frame
    summary_results <- do.call(rbind, lapply(names(results_list), function(name) {
      data.frame(Dataset = name, results_summary_list[[name]])
    }))
    
    results <- do.call(rbind, lapply(names(results_list), function(name) {
      data.frame(Dataset = name, results_list[[name]])
    }))
    
    # Display the results using stargazer
    stargazer(summary_results, type = "text", summary = FALSE,
              title = paste("Summary Statistics for Each Dataset", model, question),
              rownames = FALSE)
    
    summary_results_long <- summary_results %>%
      pivot_longer(cols = c(up, down, neutral), 
                   names_to = "Type", 
                   values_to = "Frequency")
    
    rm(summary_results)
    
    #---------------------------------------------------------------------------
    # frequency
    #---------------------------------------------------------------------------
    
    freq_plot <- ggplot(summary_results_long, aes(x = Dataset, y = Frequency, fill = Type)) +
      geom_bar(stat = "identity", position = "dodge", color = "white") +  # White outline on the bars
      scale_fill_manual(values = c("up" = "green3", "down" = "red2", "neutral" = "orange")) +  # Custom colors
      labs(title = paste("Frequency of Headline Label by Prompting Strategy", model, question, "\n"),
           x = "Dataset",
           y = "Frequency",
           fill = "Headline Type") +
      #ylim(0, 30000) + 
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  # Reduce axis text size
        axis.text.y = element_text(size = 8),  # Reduce y-axis text size
        axis.title.x = element_text(size = 9),  # Reduce x-axis title size
        axis.title.y = element_text(size = 9),  # Reduce y-axis title size
        plot.title = element_text(size = 9),  # Reduce plot title size
        legend.text = element_text(size = 8),  # Reduce legend text size
        legend.title = element_text(size = 8)  # Reduce legend title size
      )
  
    freq_list[[paste0(model, "_", question)]] <- freq_plot
    
    #---------------------------------------------------------------------------
    # confidence
    #---------------------------------------------------------------------------
    conf_plot <- ggplot(results, aes(x = Dataset, y = confidence)) +
      geom_boxplot(outlier.size = .5) +
      labs(title = paste("Boxplot of Confidence by Dataset", model, question, "\n"),
           x = "Dataset",
           y = "Confidence") +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  # Reduce axis text size
        axis.text.y = element_text(size = 8),  # Reduce y-axis text size
        axis.title.x = element_text(size = 9),  # Reduce x-axis title size
        axis.title.y = element_text(size = 9),  # Reduce y-axis title size
        plot.title = element_text(size = 9),  # Reduce plot title size
        legend.text = element_text(size = 8),  # Reduce legend text size
        legend.title = element_text(size = 8)  # Reduce legend title size
      )
    
    conf_list[[paste0(model, "_", question)]] <- conf_plot
    
    results_long <- results %>%
      filter(!is.na(headline.type.common)) %>%
      pivot_longer(cols = c(confidence), 
                   names_to = "Metric", 
                   values_to = "Value")
    
    conf_split_plot <- ggplot(results_long, aes(x = Dataset, y = Value, fill = headline.type.common)) +
      geom_boxplot(position = position_dodge(width = 0.75), outlier.size = .5) +  # Dodge position to separate the boxes
      labs(title = paste("Boxplot of Confidence by Dataset and Headline Type", model, question, "\n"),
           x = "Dataset",
           y = "Confidence",
           fill = "Headline Type") +
      scale_fill_manual(values = c("up" = "green3", "down" = "red2", "neutral" = "orange")) +
      ylim(-0.01, 1.01) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  # Reduce axis text size
        axis.text.y = element_text(size = 8),  # Reduce y-axis text size
        axis.title.x = element_text(size = 9),  # Reduce x-axis title size
        axis.title.y = element_text(size = 9),  # Reduce y-axis title size
        plot.title = element_text(size = 9),  # Reduce plot title size
        legend.text = element_text(size = 8),  # Reduce legend text size
        legend.title = element_text(size = 8)  # Reduce legend title size
      )
    
    conf_split_list[[paste0(model, "_", question)]] <- conf_split_plot
    
    #---------------------------------------------------------------------------
    # magnitude
    #---------------------------------------------------------------------------
    mag_plot <- ggplot(results, aes(x = Dataset, y = magnitude)) +
      geom_boxplot(outlier.size = .5) +
      labs(title = paste("Boxplot of Magnitude by Dataset", model, question, "\n"),
           x = "Dataset",
           y = "Magnitude") +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  # Reduce axis text size
        axis.text.y = element_text(size = 8),  # Reduce y-axis text size
        axis.title.x = element_text(size = 9),  # Reduce x-axis title size
        axis.title.y = element_text(size = 9),  # Reduce y-axis title size
        plot.title = element_text(size = 9),  # Reduce plot title size
        legend.text = element_text(size = 8),  # Reduce legend text size
        legend.title = element_text(size = 8)  # Reduce legend title size
      )
    
    mag_list[[paste0(model, "_", question)]] <- mag_plot
    
    results_long <- results %>%
      filter(!is.na(headline.type.common)) %>%
      pivot_longer(cols = c(magnitude), 
                   names_to = "Metric", 
                   values_to = "Value")
    
    rm(results)
    
    mag_split_plot <- ggplot(results_long, aes(x = Dataset, y = Value, fill = headline.type.common)) +
      geom_boxplot(position = position_dodge(width = 0.75), outlier.size = .5) +  # Dodge position to separate the boxes
      labs(title = paste("Boxplot of Magnitude by Dataset and Headline Type", model, question, "\n"),
           x = "Dataset",
           y = "Magnitude",
           fill = "Headline Type") +
      scale_fill_manual(values = c("up" = "green3", "down" = "red2", "neutral" = "orange")) +
      ylim(-0.01, 1.01) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  # Reduce axis text size
        axis.text.y = element_text(size = 8),  # Reduce y-axis text size
        axis.title.x = element_text(size = 9),  # Reduce x-axis title size
        axis.title.y = element_text(size = 9),  # Reduce y-axis title size
        plot.title = element_text(size = 9),  # Reduce plot title size
        legend.text = element_text(size = 8),  # Reduce legend text size
        legend.title = element_text(size = 8)  # Reduce legend title size
      )
    
    mag_split_list[[paste0(model, "_", question)]] <- mag_split_plot
    
  }   
}
    
    
# Arrange plots in a grid with 2 columns (one per model)
grid.arrange(grobs = freq_list, ncol = 2)
grid.arrange(grobs = conf_list, ncol = 2)
grid.arrange(grobs = conf_split_list, ncol = 2)
grid.arrange(grobs = mag_list, ncol = 2)
grid.arrange(grobs = mag_split_list, ncol = 2)




