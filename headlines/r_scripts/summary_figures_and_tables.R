library(tidyr)
library(dplyr)
library(ggplot2)
library(stargazer)
library(gridExtra)

################################################################################
# Create summary figures to compare labels across LLMs                         #
################################################################################

################################################################################
# Define helper functions                                                      #
################################################################################

# Reset the workspace by removing all objects
rm(list = ls())

# Function to standardize headline labels across different prompting strategies
convert_headline_type <- function(df) {
  df %>%
    mutate(
      headline.type.common = case_when(
        headline.type %in% c("positive", "increase") ~ "up",
        headline.type %in% c("negative", "decrease") ~ "down",
        headline.type %in% c("neutral", "uncertain") ~ "neutral",
        TRUE ~ NA_character_  # Handle any other unexpected values
      )
    )
}

# Calculate summary statistics for each dataset
calculate_stats <- function(df) {
  # Calculate mean, median, and standard deviation of confidence and magnitude
  stats <- df %>%
    summarize(
      across(c(confidence, magnitude), 
             list(mean = ~mean(.x, na.rm = TRUE),
                  median = ~median(.x, na.rm = TRUE),
                  sd = ~sd(.x, na.rm = TRUE)), 
             .names = "{.col}_{.fn}")
    )
  
  # Count the number of 'up', 'down', and 'neutral' labels
  counts <- df %>%
    count(headline.type.common) %>%
    pivot_wider(names_from = headline.type.common, 
                values_from = n, 
                values_fill = 0)
  
  # Combine statistics and label counts into a single data frame
  cbind(stats, counts)
}

################################################################################
# Iterate over all questions and models to process data and create summaries   #
################################################################################

# Initialize lists to store plots
plot_lists <- list(freq = list(), conf = list(), 
                   conf_split = list(), mag = list(), 
                   mag_split = list())

# Define questions and models to iterate over
questions <- c("q1", "q2", "q3", "q4", "q5")
models <- c("gpt-3.5-turbo", "gpt-4o-mini", "gpt-4o")
return_type <- "abnormal_CAPM"

# Loop over each combination of question and model
for (question in questions) {
  for (model in models) {
    
    ############################################################################
    # Read in data for the current model and question                          #
    ############################################################################
    
    # Print the current model and question being processed
    cat(model, question, "\n")
  
    # Define the file path based on the current model and question
    path <- paste0("../data/step6_common_sample/across_models/", return_type, "/", 
                   model, "/", question, "/")
    

    # Read in data sets for various prompting strategies
    datasets <- lapply(c("base_blanks", "base_json", "cot1", "cot2", 
                         "cot3", "persona1", "persona2", "persona3", 
                         "persona4"), 
                       function(x) read.csv(paste0(path, x, ".csv")))
    
    dataset_names <- c("Base: Fill in Blank", "Base: JSON", 
                       "COT: Careful", "COT: Explanation", 
                       "COT: Step-by-step", "Persona: Economic Agent", 
                       "Persona: Finance Expert", "Persona: Economy Expert", 
                       "Persona: Successful Trader")
    
    # Confirm that data has been read successfully
    print("read data")
    
    ############################################################################
    # Create summary tables for the current model and question                 #
    ############################################################################
    
    # Standardize headline labels across datasets
    datasets <- lapply(datasets, convert_headline_type)
    
    # Calculate statistics for each dataset and store the results
    summary_results <- bind_rows(lapply(seq_along(datasets), function(i) {
      cbind(Dataset = dataset_names[i], calculate_stats(datasets[[i]]))
    }))
    
    results <- bind_rows(lapply(seq_along(datasets), function(i) {
      cbind(Dataset = dataset_names[i], datasets[[i]])
    }))
    
    # Display the summary statistics using stargazer
    stargazer(summary_results, 
              type = "text", 
              summary = FALSE,
              title = paste("Summary Statistics for Each Dataset", 
                            model, question),
              rownames = FALSE)
    
    # Transform the summary results to a long format for plotting
    summary_results_long <- summary_results %>%
      pivot_longer(cols = c(up, down, neutral), 
                   names_to = "Type", 
                   values_to = "Frequency") %>%
      group_by(Dataset) %>%
      mutate(Percentage = Frequency / sum(Frequency) * 100) %>%
      ungroup()
    
    ############################################################################
    # Create a plot of label frequencies for the current model and question    #
    ############################################################################
    
    freq_plot <- ggplot(summary_results_long, 
                        aes(x = Dataset, y = Percentage, fill = Type)) +
      geom_bar(stat = "identity", position = "stack", color = "white") + 
      scale_fill_manual(values = c("up" = "green3", "down" = "red2", 
                                   "neutral" = "orange")) +  
      labs(title = paste("Frequency of Headline Label by Prompting Strategy", 
                         model, question, "\n"),
           x = "Dataset", y = "Percentage", fill = "Headline Type") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  
            axis.text.y = element_text(size = 8),  
            axis.title.x = element_text(size = 9),  
            axis.title.y = element_text(size = 9),  
            plot.title = element_text(size = 9),  
            legend.text = element_text(size = 8),  
            legend.title = element_text(size = 8))
    
    plot_lists$freq[[paste0(model, "_", question)]] <- freq_plot
    
    ############################################################################
    # Boxplot of label confidence for the current model/question combo.        #
    ############################################################################
    
    # Plot the distribution of confidence scores across all labels
    conf_plot <- ggplot(results, aes(x = Dataset, y = confidence)) +
      geom_boxplot(outlier.size = .5) +
      labs(title = paste("Boxplot of Confidence by Dataset", 
                         model, question, "\n"),
           x = "Dataset", y = "Confidence") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  
            axis.text.y = element_text(size = 8),  
            axis.title.x = element_text(size = 9),  
            axis.title.y = element_text(size = 9),  
            plot.title = element_text(size = 9),  
            legend.text = element_text(size = 8),  
            legend.title = element_text(size = 8))
    
    plot_lists$conf[[paste0(model, "_", question)]] <- conf_plot
    
    # Plot confidence levels by headline type
    conf_split_plot <- ggplot(results %>%
                                filter(!is.na(headline.type.common)) %>%
                                pivot_longer(cols = confidence, 
                                             names_to = "Metric", 
                                             values_to = "Value"), 
                              aes(x = Dataset, y = Value, 
                                  fill = headline.type.common)) +
      geom_boxplot(position = position_dodge(width = 0.75), 
                   outlier.size = .5) +
      labs(title = paste("Boxplot of Confidence by Dataset and Headline Type", 
                         model, question, "\n"),
           x = "Dataset", y = "Confidence", fill = "Headline Type") +
      scale_fill_manual(values = c("up" = "green3", "down" = "red2", 
                                   "neutral" = "orange")) +
      ylim(-0.01, 1.01) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  
            axis.text.y = element_text(size = 8),  
            axis.title.x = element_text(size = 9),  
            axis.title.y = element_text(size = 9),  
            plot.title = element_text(size = 9),  
            legend.text = element_text(size = 8),  
            legend.title = element_text(size = 8))
    
    plot_lists$conf_split[[paste0(model, "_", question)]] <- conf_split_plot
    
    ############################################################################
    # Create a boxplot of label magnitude for the current model/question combo #
    ############################################################################
    
    mag_plot <- ggplot(results, aes(x = Dataset, y = magnitude)) +
      geom_boxplot(outlier.size = .5) +
      labs(title = paste("Boxplot of Magnitude by Dataset", 
                         model, question, "\n"),
           x = "Dataset", y = "Magnitude") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  
            axis.text.y = element_text(size = 8),  
            axis.title.x = element_text(size = 9),  
            axis.title.y = element_text(size = 9),  
            plot.title = element_text(size = 9),  
            legend.text = element_text(size = 8),  
            legend.title = element_text(size = 8))
    
    plot_lists$mag[[paste0(model, "_", question)]] <- mag_plot
    
    mag_split_plot <- ggplot(results %>%
                               filter(!is.na(headline.type.common)) %>%
                               pivot_longer(cols = magnitude, 
                                            names_to = "Metric", 
                                            values_to = "Value"), 
                             aes(x = Dataset, y = Value, 
                                 fill = headline.type.common)) +
      geom_boxplot(position = position_dodge(width = 0.75), 
                   outlier.size = .5) +
      labs(title = paste("Boxplot of Magnitude by Dataset and Headline Type", 
                         model, question, "\n"),
           x = "Dataset", y = "Magnitude", fill = "Headline Type") +
      scale_fill_manual(values = c("up" = "green3", "down" = "red2", 
                                   "neutral" = "orange")) +
      ylim(-0.01, 1.01) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),  
            axis.text.y = element_text(size = 8),  
            axis.title.x = element_text(size = 9),  
            axis.title.y = element_text(size = 9),  
            plot.title = element_text(size = 9),  
            legend.text = element_text(size = 8),  
            legend.title = element_text(size = 8))
    
    plot_lists$mag_split[[paste0(model, "_", question)]] <- mag_split_plot
    
  }   
}

# Arrange plots in a grid with 3 columns (one per model)
grid.arrange(grobs = plot_lists$freq, ncol = 3)
grid.arrange(grobs = plot_lists$conf, ncol = 3)
grid.arrange(grobs = plot_lists$conf_split, ncol = 3)
grid.arrange(grobs = plot_lists$mag, ncol = 3)
grid.arrange(grobs = plot_lists$mag_split, ncol = 3)
