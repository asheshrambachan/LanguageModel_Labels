# ------------------------------------------------------------------
# Script Name: simulate_rhs_parallel.R
# Date: Jul 31, 2024
# Last update: Aug 21, 2024
# 
# Instructions:
# 1. Ensure R version is up to date and that all necessary libraries are installed as explained in the README.md file before running the script.
# 2. Update parameters and paths within "User Configurable Parameters" block below. After the "End of User Configurable Parameters", no changes are necessary unless you intend to modify the core functionality.
# 
# Note: This code is based on  https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/egami_et_al/code/LLM_errors.R
# -------------------------------------------------------------------

# --- User Configurable Parameters ----------------------------------
n_cores <- 50
sel_topics <- c(3, 14, 15, 19, 20) # These topics, along with "Other", are used as the Y indicators (topic dummies) for RHS regressions. The current list represents the most common major topics based on the Major/Yhuman column. 
boot <- "bayesian" # "nonparametric"

# Set directories and file paths
path.repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
path.data <- file.path(path.repo_dir, "02_llm/bills_prompts_responses_10000.csv")
path.combinations <- file.path(path.repo_dir, sprintf("04_simulation/rhs/%s/combinations_rhs.csv", boot))
path.functions <- file.path(path.repo_dir, "04_simulation/functions.R")
path.rds_dir <- file.path(path.repo_dir, sprintf("04_simulation/rhs/%s/rds", boot))
# --- End of User Configurable Parameters ---------------------------

# Load required packages quietly and custom functions
suppressPackageStartupMessages({
  library(zoo)
  library(dplyr)
  library(sandwich)
  library(lmtest)
  library(furrr)
})
source(path.functions)

# Reset processing plan
plan(sequential)

# Load combinations file
combinations <- read.csv(path.combinations)

# Set up Rds file output directory
dir.create(path.rds_dir, showWarnings=FALSE)

# Count number of remaining combinations
completed_id <- as.numeric(gsub("combination|\\.rds", "", list.files(path.rds_dir, pattern = "*.rds")))
combinations <- combinations %>% filter(!(combination_id %in% completed_id))
n_remaining_combinations <- nrow(combinations) 
cat(sprintf("Number of remaining combinations = %d\n", n_remaining_combinations))

# Load and reformat data (a global variable)
DATA <- read.csv(path.data) %>% 
  mutate(
    # Unlike LHS, we keep categorical variables as.integer since it's the dependent variable
    Senate = as.integer(Chamber == "Senate"), 
    Democrat = as.integer(Party == "Democrat"),
    Prompt = PromptingStrategyID,
    Yhuman = recode_topics(.$Major, topics=sel_topics),
    Yllm = recode_topics(.$MajorLLM, topics=sel_topics)
  ) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Yhuman, Yllm)

# Estimate run time
start_time <- Sys.time()
simulation_temp <- combinations %>%
  slice(1) %>%
  mutate(N=3) %>%
  fun.rhs_regressions(combination=., boot=boot)
end_time <- Sys.time()
duration_1 <- as.numeric(end_time - start_time, unit="hours")/3
duration_N <- duration_1 * combinations[1,]$N * n_remaining_combinations / n_cores
cat(sprintf("Expected run time = %.2f hours for N=%d and B=%d\n", duration_N, combinations[1,]$N, combinations[1,]$B))

# Adjust cores if necessary
if (n_cores > parallelly::availableCores())
  n_cores <- parallelly::availableCores()
cat(sprintf("n_cores = %d\n", n_cores))
plan(multisession, workers=n_cores)

# Run simulations
simulations <- combinations %>%
  split(.$combination_id) %>%
  unname(.) %>%
  future_map_dfr(~ fun.rhs_regressions(
      combination=.x, 
      path.rds_dir=path.rds_dir, 
      boot=boot
      ),
    .options = furrr_options(seed=TRUE) # We set the seed inside the function for reproducibility
    ) 

print(warnings())
plan(sequential)
print(simulations)