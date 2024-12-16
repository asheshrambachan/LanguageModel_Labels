# ------------------------------------------------------------------
# Script Name: run_rhs_simulations.R
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
train_proportion <- c(0.025, 0.05, 0.1, 0.25, 0.5) # Proportions for training data: 2.5%, 5%, 10%, 25%, 50%
variable <- c("Senate", "Democrat", "DW1") # Independent variables of interest
# --- End of User Configurable Parameters ---------------------------
# Set directories

# setwd("~/Documents/LanguageModel_Labels/cb_estimation/")
repo_dir <- "./cb_estimation"
data_path <- file.path(repo_dir, "Data/bills_llm.csv")
rhs_rds_dir <- file.path(repo_dir, "Temp/RHS/rds")

# Install our simUtils package
install.packages(file.path(repo_dir, "Code/simUtils_1.0.0.tar.gz"), repos = NULL, quiet = TRUE)

# Load required packages quietly
suppressPackageStartupMessages({
  library(zoo)
  library(dplyr)
  library(furrr)
  library(logger)
  library(simUtils)
})

# --- Functions ------------------------------------------------------
#' Perform Debiasing Regression for Right-Hand-Side (RHS) Simulation
#'
#' This function performs a debiasing regression for RHS variables.
#' The function calculates intermediate regressions and predicts debiased coefficients for the test data.
#'
#' @param train A data frame representing the training set, with columns V, Yhuman, Yllm, and possibly weights.
#' @param test A data frame representing the test set, with columns V, Yhuman, Yllm, and possibly weights.
#' @return A list containing:
#'   \item{coef_alpha_star}{Debiased coefficients from the regression.}
rhs_debias <- function(train, test) {
  # if no Bayesian bootstrap weights are provided, don't perform weighted LS by keeping w=NULL
  if (is.null(train$w) | is.null(test$w)){
    train$w = 1/nrow(train)
    test$w = 1/nrow(test)
  }
  
  omega <- train$w
  V_hat <- model.matrix(~ Yllm + 0, data=train)
  V <- model.matrix(~ Yhuman + 0, data=train)
  W <- train$V
  N <- nrow(train)
  
  term3 <- matrix(0, nrow=ncol(V_hat), ncol=ncol(V_hat))
  for (r in 1:N){
    V_r <- matrix(V[r,], ncol=1)
    V_hat_r <- matrix(V_hat[r,], ncol=1)
    gamma_r <- V_hat_r %*% t(V_hat_r) - V_r %*% t(V_r)
    term3 <- term3 + omega[r] * gamma_r
  }
  
  term4 <- matrix(0, nrow=ncol(V_hat), ncol=1)
  for (r in 1:N){
    V_r <- matrix(V[r,], ncol=1)
    V_hat_r <- matrix(V_hat[r,], ncol=1)
    Delta_r <- V_hat_r - V_r
    term4 <- term4 + omega[r] * Delta_r %*% W[r]
  }
  
  # (ii) Test data
  omega <- test$w
  V_hat <- model.matrix(~ Yllm + 0, data=test)
  W <- test$V
  N <- nrow(test)
  
  term1 <- matrix(0, nrow=ncol(V_hat), ncol=ncol(V_hat))
  for (r in 1:N){
    V_hat_r <- matrix(V_hat[r,], ncol=1)
    term1 <- term1 + omega[r] * V_hat_r %*% t(V_hat_r)
  }
  
  term2 <- matrix(0, nrow=ncol(V_hat), ncol=1)
  for (r in 1:N){
    V_hat_r <- matrix(V_hat[r,], ncol=1)
    term2 <- term2 + omega[r] * V_hat_r %*% W[r]
  }
  
  alpha_star <- as.numeric(solve(term1 - term3) %*% (term2 - term4))
  names(alpha_star) <- colnames(V_hat)
  
  return(list(
    coef_alpha_star = alpha_star
  ))
}

#' Simulate Right-Hand-Side (RHS) Regressions Based on a Specified Combination
#'
#' This function performs simulations for RHS regressions based on specified combinations of variables and models. It uses bootstrap sampling to estimate uncertainty in the debiased coefficients.
#'
#' @param combination A list specifying the model and variables to use in the simulation.
#' @param data A data frame containing the full dataset.
#' @param N Integer. The number of simulations to perform.
#' @param B Integer. The number of bootstrap samples to generate.
#' @param n_samples Integer. The number of samples to draw for each simulation.
#' @param type_boot Character. Specifies the type of bootstrap ("bayesian" or "nonparametric").
#' @param rds_dir Optional character. If provided, the results will be saved as RDS files in the specified directory.
#' @return A data frame summarizing the results of all simulations or a path to the saved RDS file.
rhs_simulate <- function(
    combination, 
    data,
    N,
    B,
    n_samples,
    type_boot = c("bayesian", "nonparametric"), 
    rds_dir = NULL){
  
  logger::log_appender(logger::appender_stdout)
  
  # Reformat and filter data based on the current combination
  data <- data %>% 
    filter(
      Model==combination$model, 
      Prompt==combination$prompt
    ) %>%
    mutate(
      # Unlike LHS, we keep categorical variables as.integer as they are now used as the dependent variable
      V = .[[combination$variable]]
    )

  # On all 10K bills, 
  # (i) regress V ~ Yhuman
  V_Yhuman <- robust(lm(V ~ Yhuman + 0, data), "10k_V_Yhuman")
  
  # (ii) regress V ~ Yllm
  V_Yllm <- robust(lm(V ~ Yllm + 0, data), "10k_V_Yllm")
  
  # Initialize a data frame to log all regressions, starting with summary.V_Yhuman, and summary.V_Yllm
  regressions <- summary(list(V_Yhuman, V_Yllm))
  
  # Set seed to combination_id for reproducibility 
  set.seed(combination$combination_id)
  
  # N simulations (outer loop)
  for (i in (1:N)){ 
    log.prefix <- sprintf("[combination%04d sim_number%04d]", combination$combination_id, i)
    
    # Randomly draw n_samples observations with replacement
    data_sample <- data[sample(x=nrow(data), size=n_samples, replace=TRUE), ]
    
    # Split data into train and test sets based on the predefined train_proportion. Since data_sample is already a random sample, we don't need to randomize again.
    train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
    train <- data_sample[train_idx, ]
    
    rank_Yhuman <- Matrix::rankMatrix(model.matrix(~ Yhuman + 0, data=train))[1]
    rank_Yllm <- Matrix::rankMatrix(model.matrix(~ Yllm + 0, data=train))[1]
    while ((rank_Yhuman<6) | (rank_Yllm<6)){
      logger::log_warn("{log.prefix} Redraw data_sample because rank(Yhuman)={rank_Yhuman}<6 or rank(Yllm)={rank_Yllm}<6.")
      data_sample <- data[sample(x=nrow(data), size=n_samples, replace=TRUE), ]
      train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
      train <- data_sample[train_idx, ]
      
      rank_Yhuman <- Matrix::rankMatrix(model.matrix(~ Yhuman + 0, data=train))[1]
      rank_Yllm <- Matrix::rankMatrix(model.matrix(~ Yllm + 0, data=train))[1]
    }
    test <- data_sample[-train_idx, ] %>% select(!Yhuman)

    # On data_sample, regress Yllm ~ V
    V_Yllm <- robust(lm(V ~ Yllm + 0, data_sample), "5k_V_Yllm")
    
    # (i) On train data, regress Yhuman ~ V (beta). Report robust standard errors
    V_Yhuman <- robust(lm(V ~ Yhuman + 0, train), "train_V_Yhuman")
    
    # (ii) Using train and test data, regress V_tilde ~ Ytilde, see get_debiased_rhs() for more details
    # Perform bootstrap on test_Ytilde_V to calculate standard errors and confidence intervals
    out <- withCallingHandlers(
      boot(
        fun = rhs_debias, 
        train = train, 
        test = test,
        B = B, 
        type_boot = type_boot, 
        fun_out_boot = c("coef_alpha_star"),
        regression_name = c("alpha_star")
      ),
      warning = function(w){
        logger::log_warn("{log.prefix} {conditionMessage(w)}")
        invokeRestart("muffleWarning")
      }
    )

    # Combine summaries for current iteration/sim_number, then append to all regressions 
    regressions <- bind_rows(
      regressions, 
      summary(list(
        V_Yllm, 
        V_Yhuman, 
        out$coef_alpha_star
        )) %>% 
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
# -------------------------------------------------------------------------------------

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

log_info("Proxy on the RHS")

# RHS combinations
rhs_combinations <- expand.grid(
    train_proportion = train_proportion,
    prompt = sort(unique(data$Prompt)),
    model = unique(data$Model),
    variable = variable, 
    stringsAsFactors = FALSE
  ) 

rhs_combinations_run1 <- rhs_combinations %>%
  filter(train_proportion!=0.025) %>%
  mutate(combination_id=1:n(), .before=1) # Assign a unique ID to each combination; used as seed for reproducibility

rhs_combinations_run2 <- rhs_combinations %>%
  filter(train_proportion==0.025) %>%
  mutate(combination_id=(1:n())+nrow(rhs_combinations_run1), .before=1)

rhs_combinations <- bind_rows(rhs_combinations_run1, rhs_combinations_run2)

# Filter out completed combinations
completed_id <- as.numeric(gsub("combination|\\.rds", "", list.files(rhs_rds_dir, pattern = "*.rds")))
log_info("n_combinations = {nrow(rhs_combinations)}, completed = {length(completed_id)}, remaining = {nrow(rhs_combinations)-length(completed_id)}")
rhs_combinations <- rhs_combinations %>% filter(!(combination_id %in% completed_id))

# Run RHS simulations
rhs_simulations <- rhs_combinations %>%
  split(.$combination_id) %>%
  unname(.) %>%
  future_map_dfr(
    ~ rhs_simulate(
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
log_info("End multisession")
