# ------------------------------------------------------------------
# Script Name: run_simulations.R
# Created: Jul 31, 2024
# 
# Instructions:
# 1. Ensure R version is up to date and that all necessary libraries are installed as explained in the README.md file before running the script.
# 2. Update parameters and paths within "User Configurable Parameters" block below. After the "End of User Configurable Parameters", no changes are necessary unless you intend to modify the core functionality.
# 
# Note: This code is based on  https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/egami_et_al/code/LLM_errors.R
# -------------------------------------------------------------------

# --- User Configurable Parameters ----------------------------------
n_cores <- 50
N <- 1000 # Number of simulations per a single combination
B <- 1000 # Number of bootstrap samples
n_samples <- 5000 # Number of samples drawn from 10K bill in each of the N simulations
type_boot <- "bayesian" # "nonparametric"
sel_topics <- c(3, 14, 15, 19, 20) # This list represents the most common major topics based on the Major/Yhuman column.
train_proportion <- c(0.05, 0.1, 0.25, 0.5) # Proportions for training data: 5%, 10%, 25%, 50%
variable <- c("Senate", "Democrat", "DW1") # Independent variables of interest

# Set directories
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills_v2"
data_path <- file.path(repo_dir, "Data/bills_prompts_responses.csv")
lhs_rds_dir <- file.path(repo_dir, "Temp/lhs_rds")
rhs_rds_dir <- file.path(repo_dir, "Temp/rhs_rds")
# --- End of User Configurable Parameters ---------------------------

# Install our simUtils package
install.packages(file.path(repo_dir, "Code/simUtils_1.0.0.tar.gz"), repos = NULL, quiet = TRUE)

# Load required packages quietly and custom functions
suppressPackageStartupMessages({
  library(zoo)
  library(dplyr)
  library(furrr)
})

# Setup log parameters
logger::log_appender(appender_stdout)
logger::log_warnings(muffle=TRUE)

# Reset processing plan
plan(sequential)

# Adjust cores if necessary
if (n_cores > parallelly::availableCores())
  n_cores <- parallelly::availableCores()
plan(multisession, workers=n_cores)

logger::log_info("Started a multisession with {nbrOfWorkers()} parallel workers/cores")
logger::log_info("N = {N}, B = {B}")
logger::log_info("type_boot = {type_boot}")

# Load and reformat data. 
data <- read.csv(data_path) %>% 
  rename(Prompt=PromptingStrategyID) %>%
  mutate(
    Model = if_else(Model=="gpt-3.5-turbo-0125", "gpt-3.5", "gpt-4o"),
    Senate = as.integer(Chamber == "Senate"), 
    Democrat = as.integer(Party == "Democrat"),
    Yhuman = recode_topics(.$Major, topics=sel_topics),
    Yllm = recode_topics(.$MajorLLM, topics=sel_topics)
  ) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Yhuman, Yllm)

logger::log_level(
  if(n_samples > nrow(data)) WARN else INFO, 
  "n_data = {nrow(data)}, n_samples = {n_samples}"
)


# LHS combinations
lhs_combinations <- expand.grid(
    train_proportion = train_proportion, 
    prompt = sort(unique(data$Prompt)),
    model = unique(data$Model),
    variable = variable, 
    major_topic = sel_topics, # Dependent variables of interest. These are the most common major topics based on Major/Yhuman column.
    stringsAsFactors = FALSE
  ) %>%
  mutate(combination_id=1:n(), .before=1) # Assign a unique ID to each combination; used as seed for reproducibility

# Filter out completed combinations
completed_id <- as.numeric(gsub("combination|\\.rds", "", list.files(lhs_rds_dir, pattern = "*.rds")))
logger::log_info("n_combinations = {nrow(lhs_combinations)}, completed = {length(completed_id)}, remaining = {nrow(lhs_combinations)-length(completed_id)}")
lhs_combinations <- lhs_combinations %>% filter(!(combination_id %in% completed_id))

# Run LHS simulations
lhs_simulations <- lhs_combinations %>%
  split(.$combination_id) %>%
  unname(.) %>%
  future_map_dfr(
    ~ simUtils::lhs_simulate(
      combination = .x, 
      data = data,
      N = N,
      B = B,
      n_samples = n_samples,
      type_boot = type_boot,
      rds_dir = lhs_rds_dir
    ),
    .options = furrr_options(seed=TRUE) # We reset the seed inside the function for reproducibility
  ) 

# RHS combinations
rhs_combinations <- expand.grid(
  train_proportion = train_proportion,
  prompt = sort(unique(data$Prompt)),
  model = unique(data$Model),
  variable = variable, 
  stringsAsFactors = FALSE
) %>%
  mutate(combination_id=1:n(), .before=1) # Assign a unique ID to each combination; used as seed for reproducibility

# Filter out completed combinations
completed_id <- as.numeric(gsub("combination|\\.rds", "", list.files(rhs_rds_dir, pattern = "*.rds")))
logger::log_info("n_combinations = {nrow(rhs_combinations)}, completed = {length(completed_id)}, remaining = {nrow(rhs_combinations)-length(completed_id)}")
rhs_combinations <- rhs_combinations %>% filter(!(combination_id %in% completed_id))

# Run RHS simulations
rhs_simulations <- rhs_combinations %>%
  split(.$combination_id) %>%
  unname(.) %>%
  future_map_dfr(
    ~ simUtils::rhs_simulate(
      combination=.x,
      data = data,
      N = N,
      B = B,
      n_samples = n_samples,
      type_boot = type_boot,
      rds_dir = rhs_rds_dir
    ),
    .options = furrr_options(seed=TRUE) # We reset the seed inside the function for reproducibility
  )

plan(sequential)
logger::log_info("End multisession")
