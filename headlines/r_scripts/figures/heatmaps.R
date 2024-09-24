library(dplyr)
library(ggplot2)
library(viridis)

################################################################################
# Heat maps to show (within model) agreement across prompting strategies       #
################################################################################

# Reset environment 
rm(list = ls())

# Define the questions list
questions <- c("q2")#, "q2", "q3", "q4", "q5")
return_type <- "realized"
models <- c("gpt-3.5-turbo")

# List of file names
file_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", 
                "persona1", "persona2", "persona3", "persona4")

# Function to calculate the percentage agreement between two data sets
calculate_agreement <- function(df1, df2) {
  mean(df1$headline.type == df2$headline.type, na.rm = TRUE) * 100
}

# Placeholder for results
agreement_matrices <- list()
plot_list <- list()  # List to store plots

# Read, combine, mutate, and calculate agreement matrices
for (q in questions) {
  for (m in models) {
    
    question <- q
    model <- m
    
    path <- paste0("../../data/step6_common_sample/within_model/", 
                   return_type, 
                   "/", 
                   model, 
                   "/", 
                   question, 
                   "/")
    
    # Read in datasets
    datasets <- lapply(file_names, function(file) {
      read.csv(paste0(path, file, ".csv"))
    })
    
    # Initialize matrix to store agreement percentages
    agreement_matrix <- matrix(NA, 
                               nrow = length(datasets), 
                               ncol = length(datasets))
    rownames(agreement_matrix) <- file_names
    colnames(agreement_matrix) <- file_names
    
    # Calculate pairwise agreement
    for (i in seq_along(datasets)) {
      for (j in seq_along(datasets)) {
        agreement_matrix[i, j] <- calculate_agreement(datasets[[i]], 
                                                      datasets[[j]])
      }
    }
    
    # Store the agreement matrix in the list
    agreement_matrices[[paste0(question, "_", model)]] <- agreement_matrix
    
    # Convert matrix to data frame for plotting
    agreement_df <- as.data.frame(as.table(agreement_matrix))
    colnames(agreement_df) <- c("Dataset1", "Dataset2", "Agreement")
    
    # Create a new column for text color based on Agreement value
    agreement_df <- agreement_df %>%
      mutate(TextColor = ifelse(Agreement > 70, "white", "black"))
    
    # Plot the heat map with percentage labels
    plot <- ggplot(agreement_df, 
                   aes(x = Dataset1, y = Dataset2, fill = Agreement)) +
      geom_tile() +
      geom_text(aes(label = sprintf("%.1f", Agreement),
                    color = TextColor),  
                size = 3, show.legend = FALSE) +  
      scale_fill_viridis_c(option = "rocket", direction = -1, 
                           limits = c(60, 100)) + 
      scale_color_identity() + 
      labs(title = paste("Headline Type Pairwise Agreement -", 
                         question, "-", model),
           x = "Dataset",
           y = "Dataset",
           fill = "Percent Pairwise Agreement") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1),
            legend.position = "bottom") 
    
    # Save the plot in the list
    plot_list[[paste0(question, "_", model)]] <- plot
  }
}

# Change index as needed to display/save plot of interest
plot_list[[5]]
