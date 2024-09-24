library(ggplot2)
library(dplyr)
library(tidyr)
library(stargazer)
library(gridExtra)

################################################################################
# Create a "common sample" of headlines across prompting strategies.           #
################################################################################

# Reset environment
rm(list = ls())

# Define lists of questions, models, and months to iterate over
questions <- c("q1")
models <- c("gpt-3.5-turbo")
months <- c("jan", "feb", "mar", "apr", "may", "jun", 
            "jul", "aug", "sep", "oct", "nov", "dec")

# Define return type: "abnormal_FF3" or "abnormal_CAPM" for abnormal returns or "realized" 
return_type <- "abnormal_CAPM"

# Function to calculate cumulative abnormal returns (CAR)
calculate_CAR <- function(df) {
  df %>%
    mutate(
      sum_exret_1 = exret + exret_1,
      sum_exret_5 = sum_exret_1 + exret_2 + exret_3 + exret_4 + exret_5,
      sum_exret_10 = sum_exret_5 + exret_6 + exret_7 + 
        exret_8 + exret_9 + exret_10
    ) %>%
    select(-starts_with("exret_"))
}

# Function to read, combine, mutate, and filter data for all files
read_combine_filter <- function(file_name, months, question, return_type) {
  combined_df <- bind_rows(lapply(months, function(month) {
    file_path <- paste0("../data/step5_merged_returns/", return_type, "/", 
                        model, "/", question, "/", question, "_", 
                        month, "19/", file_name)
    read.csv(file_path)
  }))
  
  if (return_type == "realized") {
    combined_df %>%
      filter(!is.na(ret_fd1) & !is.na(ret_fd5) & !is.na(ret_fd10)) %>%
      filter(!is.na(ret_ld1) & !is.na(ret_ld2) & !is.na(ret_ld3)) %>%
      filter(!is.na(headline.type) & !is.na(confidence) & 
               !is.na(magnitude))
  } else {
    calculate_CAR(combined_df) %>%
      filter(!is.na(sum_exret_1) & !is.na(sum_exret_5) & 
               !is.na(sum_exret_10)) %>%
      filter(!is.na(headline.type) & !is.na(confidence) & 
               !is.na(magnitude))
  }
}

# Iterate over each question and model
for (question in questions) {
  for (model in models) {
    
    # List of file names
    file_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", 
                    "persona1", "persona2", "persona3", "persona4")
    
    # Step 1: Read, combine, mutate, and filter data for all files
    filtered_data <- lapply(file_names, function(file_name) {
      read_combine_filter(paste0(file_name, ".csv"), months, question, 
                          return_type)
    })
    print("step 1 complete")
    
    # Step 2: Find the intersection of headlines across all datasets
    common_headlines <- Reduce(intersect, 
                               lapply(filtered_data, `[[`, "headline"))
    print("step 2 complete")
    
    # Step 3: Filter and deduplicate records based on common headlines
    final_data_unique <- lapply(filtered_data, function(df) {
      df <- df %>% filter(headline %in% common_headlines)
      duplicates <- df %>%
        filter(duplicated(headline) | duplicated(headline, 
                                                 fromLast = TRUE))
      
      deduplicated <- duplicates %>%
        group_by(headline) %>%
        summarize(
          # Handle character variables like headline.type
          headline.type = names(which.max(table(headline.type))),
          
          # Handle numeric variables (e.g., magnitude, confidence) with the new syntax for across
          across(c(magnitude, confidence), \(x) mean(x, na.rm = TRUE)),
          
          # Handle all other columns, taking the first value
          across(-c(headline.type, magnitude, confidence), first),
          
          .groups = 'drop'
        )
      
      unique_records <- df %>%
        filter(!duplicated(headline) & 
                 !duplicated(headline, fromLast = TRUE))
      
      bind_rows(deduplicated, unique_records)
    })
    print("step 3 complete")
    
    # Assign the de-duplicated data to respective variables
    list2env(setNames(final_data_unique, file_names), envir = .GlobalEnv)
    rm(final_data_unique, filtered_data)
    
    # Save the cleaned data sets
    lapply(file_names, function(file_name) {
      write.csv(get(file_name), paste0("../data/step6_common_sample/within_model/", 
                                       return_type, "/", model, "/", 
                                       question, "/", file_name, ".csv"))
    })
  }
}

