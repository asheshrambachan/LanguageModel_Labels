# ------------------------------------------------------------------
# Script Name: simulate_rhs.R
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
type.boot <- "bayesian" # c("bayesian", "nonparametric")

# Set directories and file paths
path.repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills_v2"
path.data <- file.path(path.repo_dir, "Data/bills_prompts_responses.csv")
path.utils <- file.path(path.repo_dir, "Code/utils.r")
path.rds_dir <- file.path(path.repo_dir, "Temp/rhs_rds")
# --- End of User Configurable Parameters ---------------------------


# RHS combinations
combinations <- expand.grid(
  train_proportion = c(0.05, 0.1, 0.25, 0.5), # Proportions for training data: 5%, 10%, 25%, 50%. 
  prompt = 1:12, # List of prompt IDs
  model = c("gpt-3.5", "gpt-4o"), # Model types
  variable = c("Senate", "Democrat", "DW1"), # Independent variables of interest
  stringsAsFactors = FALSE) %>%
  mutate(combination_id = 1:n(), .before = train_proportion) # Assign a unique ID to each combination; used as seed for reproducibility

# Load required packages quietly and custom functions
suppressPackageStartupMessages({
  library(zoo)
  library(dplyr)
  library(sandwich)
  library(lmtest)
  library(furrr)
  library(logger)
})
source(path.utils)

# Function to run the regression (Vtilde ~ Ytilde, data=test)
get_debiased <- function(train, test, suppressWarnings=FALSE) {
  # (i) Train data
  # beta
  # if no Bayesian bootstrap weights are provided, don't perform weighted LS by keeping w=NULL
  if (is.null(train$w) | is.null(test$w)){
    train$w = 1
    test$w = 1
  }
  V_Yhuman <- robust(lm(V ~ Yhuman + 0, weights=w, train), "train_V_Yhuman", suppressWarnings=suppressWarnings)
  coef_V_Yhuman <- coef(V_Yhuman)
  
  # delta_{V, \hat{Y}}
  V_Yllm <- robust(lm(V ~ Yllm + 0, weights=w, train), "train_V_Yllm", suppressWarnings=suppressWarnings) 
  coef_V_Yllm <- coef(V_Yllm)
  
  # delta_{Y, \hat{Y}}
  sqrt_weights <- diag(sqrt(train$w))
  Yhuman <- sqrt_weights %*% model.matrix(~ Yhuman + 0, data=train)
  Yllm <- sqrt_weights %*% model.matrix(~ Yllm + 0, data=train)
  Yhuman_Yllm <- robust(lm(Yhuman ~ Yllm + 0), "train_Yhuman_Yllm", suppressWarnings=suppressWarnings)
  coef_Yhuman_Yllm <- coef(Yhuman_Yllm) # 20*20, Yllm * Yhuman
  
  # delta_{nu, \hat{Y}} = delta_{V, \hat{Y}} - delta_{Y, \hat{Y}} beta
  coef_nu_Yllm <- coef_V_Yllm - as.vector(coef_Yhuman_Yllm %*% coef_V_Yhuman)
  
  # (ii) Test data
  Yllm <- model.matrix(~ Yllm + 0, data=test)
  
  # Ytilde: predicted Yhuman
  Ytilde <- Yllm %*% coef_Yhuman_Yllm
  colnames(Ytilde) <- sub("human","tilde", colnames(Ytilde))
  
  # V_tilde
  test$V_tilde <- test$V - Yllm %*% coef_nu_Yllm 
  
  # Regress Vtilde ~ Ytilde
  formula <- sprintf("V_tilde ~ %s + 0", paste(colnames(Ytilde), collapse=" + "))
  Vtilde_Ytilde <- lm(formula, weights=w, data=cbind(test, Ytilde))
  
  return(list(
    coef_nu_Yllm = coef_nu_Yllm, 
    coef_Vtilde_Ytilde = coef(Vtilde_Ytilde), 
    other = list( # return intermediate regressions
      V_Yhuman,
      V_Yllm,
      Yhuman_Yllm)
  ))
}

# Run RHS regressions based on the specified combination.
run_regressions <- function(
    combination, 
    data,
    N,
    B,
    n_samples,
    type.boot = c("bayesian", "nonparametric"), 
    path.rds_dir = NULL){
  
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
    # This is done and recorded in get_debiased_rhs().
    
    # (ii) Using train and test data, regress V_tilde ~ Ytilde, see get_debiased_rhs() for more details
    # Perform bootstrap on test_Ytilde_V to calculate standard errors and confidence intervals
    out <- withCallingHandlers(
      boot(
        fun = get_debiased, 
        train = train, 
        test = test,
        B = B, 
        type.boot = type.boot, 
        fun_out_boot = c("coef_nu_Yllm", "coef_Vtilde_Ytilde")
      ),
      warning = function(w){
        logger::log_warn("{log.prefix} {conditionMessage(w)}")
        invokeRestart("muffleWarning")
      }
    )
    
    # Combine summaries for current iteration/sim_number, then append to all regressions 
    regressions <- bind_rows(
      regressions, 
      summary(list(V_Yllm, out$coef_Vtilde_Ytilde, out$coef_nu_Yllm, out$other)) %>% 
        mutate(sim_number=i, .before=regression)) 
  }
  
  # Add metadata from the combination to all simulations
  regressions <- merge(combination, regressions, all=TRUE)
  
  # If path.rds_dir is provided, results will be saved as an RDS file; otherwise, they will be returned as a data.frame.
  if (is.null(path.rds_dir)){
    return(regressions)
  } else {
    # Set up Rds file output directory
    dir.create(path.rds_dir, showWarnings=FALSE)
    
    path_regressions <- file.path(path.rds_dir, sprintf("combination%05d.rds", combination$combination_id))
    saveRDS(regressions, file=path_regressions)
    logger::log_info("Saved combination at {path_regressions}")
    return(data.frame(path=path_regressions))
  }
}

# Setup log parameters
log_appender(appender_stdout)
log_warnings(muffle=TRUE)

# Reset processing plan
plan(sequential)

# Load and reformat data
sel_topics <- c(3, 14, 15, 19, 20) # These topics, along with "Other", are used as the Y indicators (topic dummies) for RHS regressions. The current list represents the most common major topics based on the Major/Yhuman column. 
data <- read.csv(path.data) %>% 
  rename(Prompt=PromptingStrategyID) %>%
  mutate(
    Model = if_else(Model=="gpt-3.5-turbo-0125", "gpt-3.5", "gpt-4o"),
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
log_info("N = {N}, B = {B}")
log_info("type.boot = {type.boot}")

# Load combinations file and filter out completed combinations
# combinations <- read.csv(path.combinations)
completed_id <- as.numeric(gsub("combination|\\.rds", "", list.files(path.rds_dir, pattern = "*.rds")))
log_info("n_combinations = {nrow(combinations)}, completed = {length(completed_id)}, remaining = {nrow(combinations)-length(completed_id)}")
combinations <- combinations %>% filter(!(combination_id %in% completed_id))

# Adjust cores if necessary
if (n_cores > parallelly::availableCores())
  n_cores <- parallelly::availableCores()

# Run simulations
plan(multisession, workers=n_cores)
log_info("Started a multisession with {nbrOfWorkers()} parallel workers/cores")

simulations <- combinations %>%
  split(.$combination_id) %>%
  unname(.) %>%
  future_map_dfr(
    ~ run_regressions(
      combination=.x,
      data = data,
      N = N,
      B = B,
      n_samples = n_samples,
      type.boot = type.boot,
      path.rds_dir=path.rds_dir
    ),
    .options = furrr_options(seed=TRUE) # We reset the seed inside the function for reproducibility
  )

plan(sequential)
log_info("End multisession")

