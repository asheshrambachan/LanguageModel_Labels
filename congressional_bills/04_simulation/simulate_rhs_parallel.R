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
n_cores <- 8
debug <- FALSE
sel_topics <- c(3, 14, 15, 19, 20) # these are the most common major topics based on Major/Yhuman column (not MajorLLM/Yllm)
boot <- "bayesian" # "nonparametric"

# Reset processing plan
plan(sequential)

# Set directories and file paths
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
path_data <- file.path(repo_dir, "02_llm/bills_prompts_responses_10000.csv")
path_functions <- file.path(repo_dir, "04_simulation/functions.R")
simulations_dir <- file.path(repo_dir, sprintf("04_simulation/rhs/%s", boot))
rds_dir <- file.path(simulations_dir, "rds")
path_combinations <- file.path(simulations_dir, "combinations_rhs.csv")

# Load custom functions
source(path_functions)

# Function to run the regression (Vtilde ~ Ytilde, data=test)
fun.test_Vtilde_Ytilde <- function(train, test, return.intermediate_regressions=FALSE){
  # if no Bayesian bootstrap weights are provided, don't perform weighted LS by setting w=1
  if ( (is.null(train$w)) | (is.null(test$w)) ){
    train$w = 1
    test$w = 1
  }
  
  # Initialize a list to store summaries of intermediate regressions, e.g., error ~ V
  regressions <- list()
  
  # Estimate error using train data and perform regression on error ~ V
  # Train data
  # beta
  train_V_Yhuman <- lm(V ~ Yhuman + 0, weights=w, data=train)
  if (return.intermediate_regressions){
    summary.train_V_Yhuman <- summary_robust(train_V_Yhuman, name="train_V_Yhuman")
    regressions <- append(regressions, summary.train_V_Yhuman)
  }
  beta <- coef(train_V_Yhuman) 
  
  # delta_{V, \hat{Y}}
  train_V_Yllm <- lm(V ~ Yllm + 0, weights=w, data=train) 
  if (return.intermediate_regressions){
    summary.train_V_Yllm <- summary_robust(train_V_Yllm, name="train_V_Yllm")
    regressions <- append(regressions, summary.train_V_Yllm)
  }
  delta_V_Yllm <- coef(train_V_Yllm)
  
  # delta_{Y, \hat{Y}}
  Yhuman <- model.matrix(~ Yhuman + 0, data=train)
  formula <- sprintf("cbind(%s) ~ Yllm + 0", paste(colnames(Yhuman), collapse=", "))
  train_Yhuman_Yllm <- lm(formula, weights = w, data=cbind(train, Yhuman)) 
  delta_Yhuman_Yllm <- coef(train_Yhuman_Yllm) # 20*20, Yllm * Yhuman
  
  if (return.intermediate_regressions){
    for (y in colnames(Yhuman)){
      formula <- sprintf("%s ~ Yllm + 0", y)
      train_Yhuman.X_Yllm <- lm(formula, weights = w, data=cbind(train, Yhuman)) 
      summary.train_Yhuman.X_Yllm <- summary_robust(train_Yhuman.X_Yllm, name=sprintf("train_%s_Yllm", y))
      regressions <- append(regressions, summary.train_Yhuman.X_Yllm)
    }
  }
  
  # delta_{nu, \hat{Y}} = delta_{V, \hat{Y}} - delta_{Y, \hat{Y}} beta
  delta_nu_Yllm <- delta_V_Yllm - as.vector(delta_Yhuman_Yllm %*% beta)
  
  # Test data
  Yllm <- model.matrix(~ Yllm + 0, data=test)
  
  # Ytilde: predicted Yhuman
  Ytilde <- Yllm %*% delta_Yhuman_Yllm
  colnames(Ytilde) <- sub("human","tilde", colnames(Ytilde))
  
  # V_tilde
  test$V_tilde <- test$V - Yllm %*% delta_nu_Yllm 
  
  # Regress Vtilde ~ Ytilde
  formula = sprintf("V_tilde ~ %s + 0", paste(colnames(Ytilde), collapse=" + "))
  test_Vtilde_Ytilde <- lm(formula, weights=w, data=cbind(test, Ytilde))
  coef.test_Vtilde_Ytilde <- coef(test_Vtilde_Ytilde)
  
  return(list(coef.train_nu_Yllm=delta_nu_Yllm, coef.test_Vtilde_Ytilde=coef.test_Vtilde_Ytilde, regressions=regressions))
}

# Run RHS regressions based on the specified combination.
# If rds_dir is provided, results will be saved as an RDS file; 
# otherwise, they will be returned as a data.frame.
fun.rhs_regressions <- function(combination, rds_dir=NULL, boot=c("bayesian", "nonparametric")){
  data_filtered <- data %>% 
    filter(Model==combination$model, 
           Prompt==combination$prompt) %>%
    mutate(V = as.integer(.[[combination$variable]]),
           # Yhuman = relevel(.$Yhuman, ref="Other"),
           # Yllm = relevel(.$Yllm, ref="Other"),
           )
  
  # On all 10K bills, regress  V ~ Yhuman
  V_Yhuman = lm(V ~ Yhuman + 0, data=data_filtered)
  summary.V_Yhuman = summary_robust(V_Yhuman, name="V_Yhuman")
  
  # Initialize a data frame to log all regressions, starting with summary.V_Yhuman
  regressions <- summary.V_Yhuman 
  
  # Set seed to combination_id for reproducibility 
  set.seed(combination$combination_id)
  
  # N simulations (outer loop)
  for (i in (1:combination$N)){ 
    
    # Randomly draw n_samples observations with replacement
    data_sample <- data_filtered[sample(x=nrow(data_filtered), size=combination$n_samples, replace=TRUE), ]
    
    # On data_sample, regress Yllm ~ V
    V_Yllm = lm(V ~ Yllm + 0, data=data_sample)
    summary.V_Yllm = summary_robust(V_Yllm, name="V_Yllm")
    
    # Split data into train and test sets based on the predefined train_proportion
    # Note: Since data_sample is already a random sample, we don't need to randomize again.
    train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
    train <- data_sample[train_idx, ]
    test <- data_sample[-train_idx, ] %>% select(!Yhuman)
    
    # (i) On train data, regress Yhuman ~ V (beta). Report robust standard errors
    # This is done and recorded in fun.test_Vtilde_Ytilde().
    
    # (ii) Using train and test data, regress V_tilde ~ Ytilde, see fun.test_Vtilde_Ytilde() for more details
    test_Vtilde_Ytilde <- fun.test_Vtilde_Ytilde(train=train, test=test, return=TRUE)
    coef.train_nu_Yllm <- test_Vtilde_Ytilde$coef.train_nu_Yllm # delta_{nu, \hat{Y}}
    coef.test_Vtilde_Ytilde <- test_Vtilde_Ytilde$coef.test_Vtilde_Ytilde
    summary.intermediate_regressions <- test_Vtilde_Ytilde$regressions
    
    # Perform bootstrap on test_Ytilde_V to calculate standard errors and confidence intervals
    boot <- match.arg(boot)
    boot.coef.train_nu_Yllm <- matrix(NA, nrow=combination$B, ncol=length(coef.train_nu_Yllm))
    boot.coef.test_Vtilde_Ytilde <- matrix(NA, nrow=combination$B, ncol=length(coef.test_Vtilde_Ytilde))
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
      out <- fun.test_Vtilde_Ytilde(train=boot.train, test=boot.test)
      boot.coef.train_nu_Yllm[b,] <- out$coef.train_nu_Yllm
      boot.coef.test_Vtilde_Ytilde[b,] <- out$coef.test_Vtilde_Ytilde
    }
    
    # Summarize results from bootstrap samples
    summary.train_nu_Yllm = summary_boot(coef.train_nu_Yllm, boot.coef.train_nu_Yllm, name="train_nu_Yllm")
    summary.test_Vtilde_Ytilde = summary_boot(coef.test_Vtilde_Ytilde, boot.coef.test_Vtilde_Ytilde, name="test_Vtilde_Ytilde")
    
    # Combine all regression summaries and add current iteration/sim_number
    regression <- bind_rows(
      summary.V_Yllm,
      summary.test_Vtilde_Ytilde, 
      summary.train_nu_Yllm,
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
  # rds_dir <- NULL
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
  future_map_dfr(~ fun.rhs_regressions(combination=.x, rds_dir=rds_dir, boot=boot), 
                 .options = furrr_options(seed=TRUE)) # We set the seed inside the function for reproducibility
plan(sequential)
print(simulations)
print(warnings())