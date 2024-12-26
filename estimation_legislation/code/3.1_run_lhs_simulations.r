# ------------------------------------------------------------------
# Script Name: run_lhs_simulations.R
# Created: Jul 31, 2024
# 
# Instructions:
# 1. Ensure R version is up to date and that all necessary libraries are installed as explained in the README.md file before running the script.
# 2. Update parameters and paths within "User Configurable Parameters" block below. After the "End of User Configurable Parameters", no changes are necessary unless you intend to modify the core functionality.
# 
# Note: This code is based on  https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/egami_et_al/code/LLM_errors.R
# -------------------------------------------------------------------

# Removing all objects
rm(list = ls())

# --- User Configurable Parameters ----------------------------------
n_cores <- 50
N <- 1000 # Number of simulations per a single combination
B <- 1000 # Number of bootstrap samples
n_samples <- 5000 # Number of samples drawn from 10K bill in each of the N simulations
type_boot <- "bayesian" # "nonparametric"
sel_topics <- c(3, 14, 15, 19, 20) # This list represents the most common major topics based on the Major/Yhuman column.
train_proportion <- c(0.025, 0.05, 0.1, 0.25, 0.5) # Proportions for training data: 2.5%, 5%, 10%, 25%, 50%
variable <- c("Senate", "Democrat", "DW1") # Independent variables of interest
# --- End of User Configurable Parameters ---------------------------

# Set directories
repo_dir <- "."
data_path <- file.path(repo_dir, "estimation_legislation/data/bills_llm.csv")
lhs_rds_dir <- file.path(repo_dir, "estimation_legislation/temp/LHS")

# Install our simUtils package
install.packages(file.path(repo_dir, "estimation_legislation/code/simUtils_1.0.0.tar.gz"), repos = NULL, quiet = TRUE)

# Load required packages quietly
suppressPackageStartupMessages({
  library(zoo)
  library(dplyr)
  library(furrr)
  library(logger)
  library(simUtils)
})

# --- Functions ------------------------------------------------------
#' Perform Debiasing Regression for Left-Hand-Side (LHS) Simulation
#'
#' This function estimates the error between two variables (Yllm and Yhuman) and performs a regression to debias the outcome (Ytilde).
#' @param train A data frame representing the training set, with columns Yllm, Yhuman, and V.
#' @param test A data frame representing the test set, with columns Yllm and V.
#' @param suppressWarnings Logical. If TRUE, suppresses warnings during model fitting.
#' @return A list containing:
#'   \item{coef_Ytilde_V}{Debiased coefficients from the regression of Ytilde on V.}
#'   \item{other}{Intermediate regression, namely error ~ V.}
lhs_debias <- function(train, test, suppressWarnings=FALSE){
  # Estimate error using train data and perform regression on error ~ V
  # if no Bayesian bootstrap weights are provided, don't perform weighted LS by setting w=1
  if (is.null(train$w) | is.null(test$w)){
    train$w = 1
    test$w = 1
  }
  train$error <- train$Yllm - train$Yhuman
  train_error_V <- robust(lm(error ~ V, weights=w, data=train), "train_error_V", suppressWarnings=suppressWarnings)
  coef_error_V <- coef(train_error_V)
  
  # Prepare design matrix for test data
  V <- model.matrix(~ V, data=test)
  
  # Predict Ytilde for test data
  test$Ytilde <- test$Yllm - V %*% as.matrix(coef_error_V, nrow=2)
  
  # Regress Ytilde ~ V and extract coefficients
  Ytilde_V <- lm(Ytilde ~ V, weights=w, data=test) 
  
  return(list(
    coef_Ytilde_V=coef(Ytilde_V), 
    other=list(train_error_V)
  ))
}

#' Simulate Left-Hand-Side (LHS) Regressions Based on a Specified Combination
#'
#' This function performs simulations for LHS regressions based on combinations of variables and models, performing bootstrap sampling to estimate uncertainty.
#' @param combination A list specifying the model and variables to use in the simulation.
#' @param data A data frame containing the full dataset.
#' @param N Integer. The number of simulations to perform.
#' @param B Integer. The number of bootstrap samples to generate.
#' @param n_samples Integer. The number of samples to draw for each simulation.
#' @param type_boot Character. Specifies the type of bootstrap ("bayesian" or "nonparametric").
#' @param rds_dir Optional character. If provided, the results will be saved as RDS files in the specified directory.
#' @return A data frame summarizing the results of all simulations or a path to the saved RDS file.
lhs_simulate <- function(
    combination, 
    data,
    N,
    B,
    n_samples,
    type_boot = c("bayesian", "nonparametric"), 
    rds_dir = NULL) {
  
  logger::log_appender(logger::appender_stdout)
  
  # Reformat and filter data based on the current combination
  data <- data %>% 
    filter(
      Model==combination$model, 
      Prompt==combination$prompt
    ) %>%
    mutate(
      Senate = as.factor(Senate),
      Democrat = as.factor(Democrat),
      V = .[[combination$variable]],
      Yhuman = as.integer(Yhuman == combination$major_topic),
      Yllm = as.integer(Yllm == combination$major_topic)
    )

  # On all 10K bills:
  # (i) regress Yhuman ~ V
  Yhuman_V <- robust(lm(Yhuman ~ V, data=data), "10k_Yhuman_V", F)
  
  # (ii) regress Yllm ~ V
  Yllm_V <- robust(lm(Yllm ~ V, data=data), "10k_Yllm_V")
  
  # Initialize a data frame to log all regressions, starting with Yhuman_V and Yllm_V
  regressions <- summary(list(Yhuman_V, Yllm_V))
  
  # Set seed to combination_id for reproducibility
  set.seed(combination$combination_id)
  
  # N simulations (outer loop)
  for (i in (1:N)){
    log.prefix <- sprintf("[combination%04d sim_number%04d]", combination$combination_id, i)
    
    # Randomly draw n_samples observations with replacement
    data_sample <- data[sample(x=nrow(data), size=n_samples, replace=TRUE), ]
    
    # On data_sample, regress Yllm ~ V
    Yllm_V <- robust(lm(Yllm ~ V, data=data_sample), "5k_Yllm_V")
    
    # Split data into train and test sets based on the predefined train_proportion
    # Note: Since data_sample is already a random sample, we don't need to randomize again.
    train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
    train <- data_sample[train_idx, ]
    test <- data_sample[-train_idx, ] %>% select(!Yhuman)
    
    # (i) On train data, regress Yhuman ~ V. Report robust standard errors
    Yhuman_V <- robust(lm(Yhuman ~ V, data=train), "train_Yhuman_V")
    
    # (ii) Using train and test data, regress Ytilde ~ V, see debias.lhs() for more details
    # Perform bootstrap on test_Ytilde_V to calculate standard errors and confidence intervals
    out <- withCallingHandlers(
      boot(
        fun = lhs_debias,
        train = train,
        test = test,
        B = B,
        type_boot = type_boot,
        fun_out_boot = "coef_Ytilde_V",
        regression_name = "Ytilde_V"
      ),
      warning = function(w){
        logger::log_warn("{log.prefix} {conditionMessage(w)}")
        invokeRestart("muffleWarning")
      }
    )
    
    # Combine all summaries for current iteration/sim_number, then append to all regressions
    regressions <- bind_rows(
      regressions,
      summary(list(Yllm_V, Yhuman_V, out$coef_Ytilde_V, out$other)) %>%
        mutate(sim_number=i, .before=1))
  }
  
  # Add metadata from the combination to all simulations
  regressions <- merge(combination, regressions, all=TRUE)
  
  # If rds_dir is provided, results will be saved as an RDS file; otherwise, they will be returned as a data.frame.
  if (is.null(rds_dir)){
    return(regressions)
  } else {
    # Set up Rds file output directory
    dir.create(rds_dir, showWarnings=FALSE, recursive = TRUE)
    path_regressions <- file.path(rds_dir, sprintf("combination%05d.rds", combination$combination_id))
    saveRDS(regressions, file=path_regressions)
    logger::log_info("Saved combination at {path_regressions}")
    return(data.frame(path=path_regressions))
  }
}
# ---------------------------------------------------------------------------------------

# Setup log parameters
log_appender(appender_stdout)
log_warnings(muffle=TRUE)

# Reset processing plan
plan(sequential)

# Adjust cores if necessary
if (n_cores > parallelly::availableCores())
  n_cores <- parallelly::availableCores()
plan(multisession, workers=n_cores)

log_info("Started a multisession with {nbrOfWorkers()} parallel workers/cores")
log_info("N = {N}, B = {B}")
log_info("type_boot = {type_boot}")

# Load and reformat data. 
data <- read.csv(data_path) %>% 
  rename(Prompt=PromptingStrategyID) %>%
  mutate(
    Senate = as.integer(Chamber == "Senate"), 
    Democrat = as.integer(Party == "Democrat"),
    Yhuman = recode_topics(.$Major, topics=sel_topics),
    Yllm = recode_topics(.$MajorLLM, topics=sel_topics)
  ) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Yhuman, Yllm)

log_level(
  if(n_samples > nrow(data)) WARN else INFO, 
  "n_data = {nrow(data)}, n_samples = {n_samples}"
)

log_info("Proxy on the LHS")

# LHS combinations
lhs_combinations <- expand.grid(
    train_proportion = train_proportion, 
    prompt = sort(unique(data$Prompt)),
    model = unique(data$Model),
    variable = variable, 
    major_topic = sel_topics, # Dependent variables of interest. These are the most common major topics based on Major/Yhuman column.
    stringsAsFactors = FALSE
  )
  
lhs_combinations_run1 <- lhs_combinations %>%
  filter(train_proportion!=0.025) %>%
  mutate(combination_id=1:n(), .before=1) # Assign a unique ID to each combination; used as seed for reproducibility

lhs_combinations_run2 <- lhs_combinations %>%
  filter(train_proportion==0.025) %>%
  mutate(combination_id=(1:n())+nrow(lhs_combinations_run1), .before=1)

lhs_combinations <- bind_rows(lhs_combinations_run1, lhs_combinations_run2)

# Filter out completed combinations
completed_id <- as.numeric(gsub("combination|\\.rds", "", list.files(lhs_rds_dir, pattern = "*.rds")))
log_info("n_combinations = {nrow(lhs_combinations)}, completed = {length(completed_id)}, remaining = {nrow(lhs_combinations)-length(completed_id)}")
lhs_combinations <- lhs_combinations %>% filter(!(combination_id %in% completed_id))

# Run LHS simulations
lhs_simulations <- lhs_combinations %>%
  split(.$combination_id) %>%
  unname(.) %>%
  future_map_dfr(
    ~ lhs_simulate(
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

plan(sequential)
log_info("End multisession")
