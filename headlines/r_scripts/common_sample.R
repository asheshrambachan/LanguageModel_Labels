library(ggplot2)
library(dplyr)
library(tidyr)
library(stargazer)
library(gridExtra)

rm(list = ls())

questions <- c("q1")
models <- c("gpt-4o")

calculate_CAR <- function(df) {
  df <- df %>%
    mutate(
      sum_exret_1 = exret + exret_1,
      sum_exret_5 = sum_exret_1 + exret_2 + exret_3 + exret_4 + exret_5,
      sum_exret_10 = sum_exret_5 + exret_6 + exret_7 + exret_8 + exret_9 + exret_10
    ) %>%
    select(-c(exret_1, exret_2, exret_3, exret_4, exret_5, exret_6, exret_7, exret_8, exret_9, exret_10))
}

for (q in questions) {
  for (model in models) {
    # Define the question and the list of months
    question <- q
    months <- c("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", 
                "octfirst", "octsecond")
    year = "19"
    return_type = "CAPM" # edit as needed, we're doing this 1 by 1 
    
    # List of file names
    file_names <- c("base_blanks", "base_json", "cot1", "cot2", "cot3", 
                    "persona1", "persona2", "persona3", "persona4")
    
    # Function to read, combine, mutate, and filter data for all files
    read_combine_filter <- function(file_name, months, question) {
      
      # Initialize an empty data frame to store combined data
      combined_df <- data.frame()  
      
      for (month in months) {
        file_path <- paste0("../data/step5_returns_merged/", 
                            return_type, "/", 
                            model, "/", 
                            question, "/",  
                            question, "_", month, "19/", 
                            file_name)
        
        print(file_name)
        month_df <- read.csv(file_path)
        
        # Combine data frames
        combined_df <- bind_rows(combined_df, month_df) 
      }
      
      print(colnames(combined_df))
      
      if(return_type == "cumulative"){
        filtered_df <- combined_df %>%
          # post-headline returns not null 
          filter(!is.na(ret_fd1) & !is.na(ret_fd5) & !is.na(ret_fd10)) %>%
          
          # controls not null 
          filter(!is.na(ret_ld1) & !is.na(ret_ld2) & !is.na(ret_ld3)) %>%
          
          # labels are legit 
          filter(!is.na(headline.type)) %>%
          filter(!is.na(confidence)) %>%
          filter(!is.na(magnitude))
      }
      else {
        combined_df <- calculate_CAR(combined_df)
        filtered_df <- combined_df %>%
          # post-headline returns not null 
          filter(!is.na(sum_exret_1) & !is.na(sum_exret_5) & !is.na(sum_exret_10)) %>%
          
          # labels are legit 
          filter(!is.na(headline.type)) %>%
          filter(!is.na(confidence)) %>%
          filter(!is.na(magnitude))
      }
      
      return(filtered_df)
    }
    
    # Step 1: Read, combine, mutate, and filter data for all files
    filtered_data <- lapply(file_names, function(file_name) {
      read_combine_filter(paste0(file_name, ".csv"), months, question)
    })
    print("step 1 complete")
    
    # Step 2: Find the intersection of headlines across all filtered datasets
    common_headlines <- Reduce(intersect, lapply(filtered_data, function(df) df$headline))
    print("step 2 complete")
    
    filtered_data <- lapply(filtered_data, function(df) {
      df %>%
        filter(headline %in% common_headlines) 
    })
    
    # Step 3: Filter each dataset based on the common headlines
    final_data_unique <- lapply(filtered_data, function(df) {
      duplicates <- df %>%
        filter(headline %in% common_headlines) %>%
        filter(duplicated(headline) | duplicated(headline, fromLast = TRUE))
      
      deduplicated <- duplicates %>%
        group_by(headline) %>%
        summarize(
          headline.type = names(which.max(table(headline.type))),
          magnitude = mean(magnitude, na.rm = TRUE),
          confidence = mean(confidence, na.rm = TRUE),
          across(-c(headline.type, confidence, magnitude), first),
          .groups = 'drop'
        )
      
      unique_records <- df %>%
        filter(headline %in% common_headlines) %>%
        filter(!duplicated(headline) & !duplicated(headline, fromLast = TRUE))
      
      final_df <- bind_rows(deduplicated, unique_records)
      return(final_df)
    })
    print("step 4 complete")
    
    # Assign the deduplicated data to respective variables
    base_blanks <- final_data_unique[[1]]
    base_json <- final_data_unique[[2]]
    cot1 <- final_data_unique[[3]]
    cot2 <- final_data_unique[[4]]
    cot3 <- final_data_unique[[5]]
    persona1 <- final_data_unique[[6]]
    persona2 <- final_data_unique[[7]]
    persona3 <- final_data_unique[[8]]
    persona4 <- final_data_unique[[9]]
    
    rm(final_data_unique, filtered_data)
    
    write.csv(base_blanks, paste0("../data/step6_common_sample/", 
                                  return_type, "/", 
                                  model, "/", 
                                  question, 
                                  "/base_blanks.csv"))
    
    write.csv(base_json, paste0("../data/step6_common_sample/", 
                                  return_type, "/", 
                                  model, "/", 
                                  question, 
                                  "/base_json.csv"))
    
    write.csv(persona1, paste0("../data/step6_common_sample/", 
                                  return_type, "/", 
                                  model, "/", 
                                  question, 
                                  "/persona1.csv"))
    
    write.csv(persona2, paste0("../data/step6_common_sample/", 
                                  return_type, "/", 
                                  model, "/", 
                                  question, 
                                  "/persona2.csv"))
    
    write.csv(persona3, paste0("../data/step6_common_sample/", 
                                  return_type, "/", 
                                  model, "/", 
                                  question, 
                                  "/persona3.csv"))
    
    write.csv(persona4, paste0("../data/step6_common_sample/", 
                                  return_type, "/", 
                                  model, "/", 
                                  question, 
                                  "/persona4.csv"))
    
    write.csv(cot1, paste0("../data/step6_common_sample/", 
                                  return_type, "/", 
                                  model, "/", 
                                  question, 
                                  "/cot1.csv"))
    
    write.csv(cot2, paste0("../data/step6_common_sample/", 
                                  return_type, "/", 
                                  model, "/", 
                                  question, 
                                  "/cot2.csv"))
    
    write.csv(cot3, paste0("../data/step6_common_sample/", 
                                  return_type, "/", 
                                  model, "/", 
                                  question, 
                                  "/cot3.csv"))
  }
}
