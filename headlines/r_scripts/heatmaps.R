library(dplyr)
library(ggplot2)
library(viridis)

# Define the questions list
questions <- c("q1", "q2", "q3", "q4", "q5")
return_type <- "CAPM"
models <- c("gpt-3.5-turbo", "gpt-4o-mini")

# Function to mutate the data frame with new columns
mutate_data <- function(df, question) {
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
        neutral.magnitude = neutral * magnitude
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
        uncertain.magnitude = uncertain * magnitude
      )
  }
}

# List of file names
file_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", 
                "persona1", "persona2", "persona3", "persona4")

# Function to calculate the percentage agreement between two datasets
calculate_agreement <- function(df1, df2) {
  mean(df1$headline.type == df2$headline.type, na.rm = TRUE) * 100
}

# Placeholder for results
agreement_matrices <- list()
plot_list <- list()  # List to store plots

# Read, combine, mutate, and calculate agreement matrices
for (q in 1:length(questions)) {
  for (m in 1:length(models)) {
    
    question <- questions[q]
    model <- models[m]
    
    path <- paste0("../data/step6_common_sample/", return_type, "/", model, "/", question, "/")
    
    # Read in datasets
    datasets <- lapply(file_names, function(file) {
      df <- read.csv(paste0(path, file, ".csv"))
      mutate_data(df, question)
    })
    
    # Initialize matrix to store agreement percentages
    agreement_matrix <- matrix(NA, nrow = length(datasets), ncol = length(datasets))
    rownames(agreement_matrix) <- file_names
    colnames(agreement_matrix) <- file_names
    
    # Calculate pairwise agreement
    for (i in 1:length(datasets)) {
      for (j in 1:length(datasets)) {
        agreement_matrix[i, j] <- calculate_agreement(datasets[[i]], datasets[[j]])
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
    
    # Plot the heatmap with percentage labels, reversed color scale, and conditional text color
    p <- ggplot(agreement_df, aes(x = Dataset1, y = Dataset2, fill = Agreement)) +
      geom_tile() +
      geom_text(aes(label = sprintf("%.1f", Agreement),
                    color = TextColor),  # Use TextColor column for text color
                size = 3, show.legend = FALSE) +  # Remove text color legend
      scale_fill_viridis_c(option = "rocket", direction = -1) +  # Reverse color scale
      scale_color_identity() +  # Use the actual color values provided in TextColor
      labs(title = paste("Headline Type Pairwise Agreement -", question, "-", model),
           x = "Dataset",
           y = "Dataset",
           fill = "Percent Pairwise Agreement") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1),
            legend.position = "bottom")  # Position the legend at the bottom
    
    # Save the plot in the list
    plot_list[[paste0(question, "_", model)]] <- p
  }
}

# Display the plots one by one
plot_list[[1]]
