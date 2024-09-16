require(dplyr)
require(ggplot2)

# Set the working directory 
repo_dir <- "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills"

# --- LHS combinations --------------------------------------------------
simulation_dir <- file.path(repo_dir, "04_simulation/output/lhs")
dir.create(simulation_dir, showWarnings=FALSE, recursive=TRUE)

combinations <- expand.grid(
  train_proportion = c(0.05, 0.1, 0.25, 0.5), # Proportions for training data: 5%, 10%, 25%, 50%
  prompt = 1:12, # List of prompt IDs
  model = c("gpt-3.5", "gpt-4o"), # Model types
  variable = c("Senate", "Democrat", "DW1"), # Independent variables of interest
  major_topic = c(3, 14, 15, 19, 20), # Dependent variables of interest. These are the most common major topics based on Major/Yhuman column.
  stringsAsFactors = FALSE) %>%
  mutate(combination_id = 1:n(), .before = train_proportion) # Assign a unique ID to each combination; used as seed for reproducibility

# Save the merged combinations to a csv file
write.csv(combinations, file.path(simulation_dir, "combinations.csv"), row.names=FALSE)


# --- RHS combinations --------------------------------------------------
simulation_dir <- file.path(repo_dir, "04_simulation/output/rhs")
dir.create(simulation_dir, showWarnings=FALSE, recursive=TRUE)

combinations <- expand.grid(
  train_proportion = c(0.05, 0.1, 0.25, 0.5), # Proportions for training data: 5%, 10%, 25%, 50%. 
  prompt = 1:12, # List of prompt IDs
  model = c("gpt-3.5", "gpt-4o"), # Model types
  variable = c("Senate", "Democrat", "DW1"), # Independent variables of interest
  stringsAsFactors = FALSE) %>%
  mutate(combination_id = 1:n(), .before = train_proportion) # Assign a unique ID to each combination; used as seed for reproducibility

# Save the merged combinations to a csv file
write.csv(combinations, file.path(simulation_dir, "combinations.csv"), row.names=FALSE)