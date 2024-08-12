# title: "Simulations"
# date: "July 31, 2024"
# output: html_document
# This code is based on https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/egami_et_al/code/LLM_errors.R

# Load required packages quietly
suppressPackageStartupMessages({
  library(zoo)
  library(dplyr)
  library(sandwich)
  library(lmtest)
  library(furrr)
})

# Arguments not specified in combinations.csv
n_cores <- 30
debug <- FALSE
sel_topics <- c(3, 14, 15, 19, 20) # these are the most common major topics based on Major/Yhuman column (not MajorLLM/Yllm)

# Reset processing plan
plan(sequential)

# Set directories and file paths
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
simulation_dir <- file.path(repo_dir, "04_simulation")
rds_dir <- file.path(simulation_dir, "lhs_rds")
path_combinations <- file.path(simulation_dir, "lhs_combinations.csv")
path_data <- file.path(repo_dir, "02_llm/bills_prompts_responses_10000.csv")
path_functions <- file.path(simulation_dir, "functions.R")

# Load custom functions
source(path_functions)

# Function to run the regression (Ytilde ~ V, data=test)
fun.test_Ytilde_V <- function(train, test, return.intermediate_regressions=FALSE){
  if (is.null(train$w)) # if no Bayesian bootstrap weights are provided, don't perform weighted LS by setting w=1
    train$w = 1 
  
  if (is.null(test$w))
    test$w = 1
  
  # Initialize a list to store summaries of intermediate regressions, e.g., error ~ V
  regressions <- list()
  
  # Estimate error using train data and perform regression on error ~ V
  train$error <- train$Yllm - train$Yhuman
  train_error_V <- lm(error ~ V, weights=w, data=train)
  delta_error_V <- coef(train_error_V)
  if (return.intermediate_regressions){
    summary.train_error_V <- summary_robust(train_error_V, name="train_error_V")
    regressions <- append(regressions, summary.train_error_V)
  }
  
  # Prepare design matrix for test data
  V <- model.matrix(~ V, data=test)
  
  # Predict Ytilde for test data
  test$Ytilde <- test$Yllm - V %*% as.matrix(delta_error_V, nrow=2)
  
  # Regress Ytilde ~ V and extract coefficients
  test_Ytilde_V <- lm(Ytilde ~ V, weights=w, data=test) 
  coef.test_Ytilde_V <- coef(test_Ytilde_V)
  
  return(list(coef.test_Ytilde_V=coef.test_Ytilde_V, regressions=regressions))
}

# Run LHS regressions based on the specified combination.
# If rds_dir is provided, results will be saved as an RDS file; 
# otherwise, they will be returned as a data.frame.
fun.lhs_regressions <- function(combination, rds_dir=NULL, boot=c("nonparametric", "bayesian")){
  data_filtered <- data %>% 
    filter(Model==combination$model, 
           Prompt==combination$prompt) %>%
    mutate(V = .[[combination$variable]],
           Yhuman = as.integer(Yhuman == combination$major_topic),
           Yllm = as.integer(Yllm == combination$major_topic))
  
  # On all 10K bills, regress Yhuman ~ V
  Yhuman_V <- lm(Yhuman ~ V, data=data_filtered)
  summary.Yhuman_V <- summary_robust(Yhuman_V, name="Yhuman_V")
  
  # Initialize a data frame to log all regressions, starting with summary.Yhuman_V
  regressions <- summary.Yhuman_V 
  
  # Set seed to combination_id for reproducibility 
  set.seed(combination$combination_id)
  
  # N simulations (outer loop)
  for (i in (1:combination$N)){ 
    
    # Randomly draw n_samples observations with replacement
    data_sample <- data_filtered[sample(x=nrow(data_filtered), size=combination$n_samples, replace=TRUE), ]
    
    # On data_sample, regress Yllm ~ V
    Yllm_V <- lm(Yllm ~ V, data=data_sample)
    summary.Yllm_V <- summary_robust(Yllm_V, name="Yllm_V")
    
    # Split data into train and test sets based on the predefined train_proportion
    # Note: Since data_sample is already a random sample, we don't need to randomize again.
    train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
    train <- data_sample[train_idx, ]
    test <- data_sample[-train_idx, ] %>% select(!Yhuman)
    
    # (i) On train data, regress Yhuman ~ V. Report robust standard errors
    train_Yhuman_V <- lm(Yhuman ~ V, data=train)
    summary.train_Yhuman_V <- summary_robust(train_Yhuman_V, name="train_Yhuman_V")
    
    # (ii) Using train and test data, regress Ytilde ~ V, see fun.test_Ytilde_V() for more details
    test_Ytilde_V <- fun.test_Ytilde_V(train=train, test=test, return=TRUE)
    coef.test_Ytilde_V <- test_Ytilde_V$coef.test_Ytilde_V
    summary.intermediate_regressions <- test_Ytilde_V$regressions
    
    # Perform bootstrap on test_Ytilde_V to calculate standard errors and confidence intervals
    boot <- match.arg(boot)
    boot.coef.test_Ytilde_V <- matrix(NA, nrow=combination$B, ncol=length(coef.test_Ytilde_V))
    for (b in 1:combination$B){
      boot.train <- train
      boot.test <- test
      
      # Resample or change sample weights if a bootstrap method is specified
      if (boot=="nonparametric"){
        boot.train <- boot.train[sample(x=nrow(boot.train), replace=TRUE), ]
        boot.test <- boot.test[sample(x=nrow(boot.test), replace=TRUE), ]
      } else if (boot=="bayesian") {
        w_train <- rgamma(nrow(train), shape=1, scale=1) 
        w_test <- rgamma(nrow(test), shape=1, scale=1)
        boot.train$w <- w_train/sum(w_train)
        boot.test$w <- w_test/sum(w_test)
      } 
      out <- fun.test_Ytilde_V(train=boot.train, test=boot.test)
      boot.coef.test_Ytilde_V[b,] <- out$coef.test_Ytilde_V
    }
    
    # Summarize results from bootstrap samples
    summary.test_Vtilde_Ytilde <- summary_boot(coef.test_Ytilde_V, boot.coef.test_Ytilde_V, name="test_Ytilde_V")
    
    # Combine all regression summaries and add current iteration/sim_number
    regression <- bind_rows(
      summary.Yllm_V, 
      summary.train_Yhuman_V, 
      summary.test_Vtilde_Ytilde, 
      summary.intermediate_regressions) %>% 
      mutate(sim_number=i, .before=regression)
    
    # Append to all regressions 
    regressions <- bind_rows(regressions, regression) 
  }
  
  # Add metadata from the combination to all simulations
  regressions <- merge(combination, regressions, all=TRUE)
  
  if (is.null(rds_dir)){
    return (regressions)
  } else {
    path_regressions = file.path(rds_dir, sprintf("combination%05d.rds", combination$combination_id))
    saveRDS(regressions, file=path_regressions)
    return(data.frame(path=path_regressions))
  }
}

# Load combinations file
combinations <- read.csv(path_combinations)

# Set up Rds file output directory
dir.create(rds_dir, showWarnings=FALSE)

# Count number of remaining combinations
completed_id <- as.numeric(gsub("combination|\\.rds", "", list.files(rds_dir, pattern = "*.rds")))
combinations <- combinations %>% filter(!(combination_id %in% completed_id))
n_remaining_combinations <- nrow(combinations) 
cat(sprintf("Number of remaining combinations = %d\n", n_remaining_combinations))

# Debug mode adjustments
if (debug) {
  cat("DEBUG: Limiting to N=3 and selecting first 3 combinations\n")
  combinations <- combinations %>% 
    slice(1:3) %>% 
    mutate(N=3)
  rds_dir <- NULL
  # rds_dir <- sprintf("%s_debug", rds_dir)
  # dir.create(rds_dir, showWarnings = FALSE)
}

# Load and reformat data
data <- read.csv(path_data) %>% 
  mutate(
    Senate = as.factor(as.integer(Chamber == "Senate")),
    Democrat = as.factor(as.integer(Party == "Democrat")),
    Prompt = PromptingStrategyID,
    Yhuman = recode_topics(.$Major, topics=sel_topics),
    Yllm = recode_topics(.$MajorLLM, topics=sel_topics)
  ) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Yhuman, Yllm)

# Estimate run time
start_time <- Sys.time()
simulation_temp <- combinations %>% 
  slice(1) %>%
  mutate(N=10) %>% 
  fun.lhs_regressions(combination=.)
end_time <- Sys.time()
duration_1 <- as.numeric(end_time - start_time, unit="hours")/10
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
  future_map_dfr(~ fun.lhs_regressions(combination=.x, rds_dir=rds_dir), 
    .options = furrr_options(seed=TRUE)) # We set the seed inside the function for reproducibility
plan(sequential)
print(simulations)