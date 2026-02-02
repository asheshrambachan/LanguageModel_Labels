library(dplyr)
repo_dir <- "."
data_path <- file.path(repo_dir, "estimation_legislation/data/bills_llm.csv")
rhs_rds_dir <- file.path(repo_dir, "estimation_legislation/temp/RHS")

n_cores <- 19
b_cores <- 6
N <- 1000 # Number of simulations per a single combination
B <- 1000 # Number of bootstrap samples
n_samples <- 5000 # Number of samples drawn from 10K bill in each of the N simulations
type_boot <- "bayesian" # "nonparametric"
sel_topics <- c(3, 14, 15, 19, 20) # This list represents the most common major topics based on the Major/Yhuman column.
train_proportion <- c(0.025, 0.05, 0.1, 0.25, 0.5) # Proportions for training data: 2.5%, 5%, 10%, 25%, 50%
variable <- c("Senate", "Democrat", "DW1") # Independent variables of interest

recode_topics <- function(x, topics){
  x_recoded <- addNA(factor(x, levels=topics))  # Recode factor levels, including NA
  n <- nlevels(x_recoded)
  if (is.na(levels(x_recoded)[n]))
    levels(x_recoded)[n] <- "Other" # Label NA levels as "Other"
  return(x_recoded)
}

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
  
  rank_inv_term <- Matrix::rankMatrix(term1 - term3)[1]
  if (rank_inv_term < 6){
    warning("Singular solve(term1 - term3)")
    alpha_star <- rep(NA, ncol(V_hat))
  }
  else {
    alpha_star <- as.numeric(solve(term1 - term3) %*% (term2 - term4))
  }
  names(alpha_star) <- gsub("Yhuman|Yllm|Ytilde", "",  colnames(V_hat))
  
  return(alpha_star)
}

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
# filter(Model %in% c("gpt-5-mini", "gpt-5-nano")) # c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13")

# # RHS combinations
# rhs_combinations <- expand.grid(
#   train_proportion = train_proportion,
#   prompt = sort(unique(data$Prompt)),
#   model = unique(data$Model),
#   variable = variable, 
#   stringsAsFactors = FALSE
# ) 
# 
# rhs_combinations_run1 <- rhs_combinations %>%
#   filter(train_proportion!=0.025) %>%
#   mutate(combination_id=1:n(), .before=1) # Assign a unique ID to each combination; used as seed for reproducibility
# 
# rhs_combinations_run2 <- rhs_combinations %>%
#   filter(train_proportion==0.025) %>%
#   mutate(combination_id=(1:n())+nrow(rhs_combinations_run1), .before=1)
# 
# rhs_combinations <- bind_rows(rhs_combinations_run1, rhs_combinations_run2)
# 
# # Filter out completed combinations
# completed_id <- as.numeric(gsub("combination|\\.rds", "", list.files(rhs_rds_dir, pattern = "^combination1.*\\.rds$")))
# log_info("n_combinations = {nrow(rhs_combinations)}, completed = {length(completed_id)}, remaining = {nrow(rhs_combinations)-length(completed_id)}")
# rhs_combinations <- rhs_combinations %>% filter(!(combination_id %in% completed_id) | combination_id %in% c(21, 73, 300, 354))

rhs_combinations <- readRDS("./estimation_legislation/temp/rhs_combinations.rds")

for (x in 1:nrow(rhs_combinations)){
  combination <- rhs_combinations %>% slice(x)
  
  # Reformat and filter data based on the current combination
  data_x <- data %>% 
    filter(
      Model==combination$model, 
      Prompt==combination$prompt
    ) %>%
    mutate(
      # Unlike LHS, we keep categorical variables as.integer as they are now used as the dependent variable
      V = .[[combination$variable]]
    )
  
  # N simulations (outer loop)
  sim_loop <- function(i){
    # Randomly draw n_samples observations with replacement
    data_sample <- data_x[sample(x=nrow(data_x), size=n_samples, replace=TRUE), ]
    
    # Split data into train and test sets based on the predefined train_proportion. Since data_sample is already a random sample, we don't need to randomize again.
    train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
    train <- data_sample[train_idx, ]
    test <- data_sample[-train_idx, ] %>% select(!Yhuman)
    
    rank_Yhuman_train <- Matrix::rankMatrix(model.matrix(~ Yhuman + 0, data=train))[1]
    rank_Yllm_train <- Matrix::rankMatrix(model.matrix(~ Yllm + 0, data=train))[1]
    rank_Yllm_test <- Matrix::rankMatrix(model.matrix(~ Yllm + 0, data=test))[1]
    coef_value <- rhs_debias(train = train, test = test)
    
    while (
      (rank_Yhuman_train < 6) | 
      (rank_Yllm_train < 6) | 
      (rank_Yllm_test < 6) | 
      any(is.na(coef_value)) |
      any(abs(coef_value) > 1e11)
    ){
      data_sample <- data_x[sample(x=nrow(data_x), size=n_samples, replace=TRUE), ]
      train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
      train <- data_sample[train_idx, ]
      test <- data_sample[-train_idx, ] %>% select(!Yhuman)
      
      rank_Yhuman_train <- Matrix::rankMatrix(model.matrix(~ Yhuman + 0, data=train))[1]
      rank_Yllm_train <- Matrix::rankMatrix(model.matrix(~ Yllm + 0, data=train))[1]
      rank_Yllm_test <- Matrix::rankMatrix(model.matrix(~ Yllm + 0, data=test))[1]
      coef_value <- rhs_debias(train = train, test = test)
    }
    
    # On data_sample, regress Yllm ~ V
    V_Yllm <- simUtils::robust(lm(V ~ Yllm + 0, data_sample), "5k_V_Yllm")
    
    # (i) On train data, regress Yhuman ~ V (beta). Report robust standard errors
    V_Yhuman <- simUtils::robust(lm(V ~ Yhuman + 0, train), "train_V_Yhuman")
    
    # (ii) Using train and test data, regress V_tilde ~ Ytilde, see get_debiased_rhs() for more details
    # Perform bootstrap on test_Ytilde_V to calculate standard errors and confidence intervals
    coef_value <- rhs_debias(train = train, test = test)
    
    # Bootstrap function
    boot_loop <- function(b) {
      train_boot <- train
      test_boot <- test
      
      w_train <- stats::rgamma(nrow(train_boot), shape=1, scale=1)
      w_test <- stats::rgamma(nrow(test_boot), shape=1, scale=1)
      train_boot$w <- w_train/sum(w_train)
      test_boot$w <- w_test/sum(w_test)
      
      out_boot <- rhs_debias(train = train_boot, test = test_boot)
      return(out_boot)
    }
    
    boot <- bind_rows(parallel::mclapply(1:B, boot_loop, mc.cores = b_cores))
    
    # Calculate standard errors from bootstrap samples
    se_value <- apply(boot, 2, stats::sd)
    ci <- function(x, alpha=0.05){
      probs <- c(alpha/2, 1-alpha/2)
      ci_transposed <- apply(x, 2, FUN=stats::quantile, probs=probs)
      ci_val <- t(ci_transposed)
      colnames(ci_val) <- sprintf("%.1f%%", probs*100)
      return(ci_val)
    }
    ci_value <- ci(boot)
    t <- coef_value/se_value
    
    # Simplify coefficient names
    coef_alpha_star <- data.frame(
      regression="alpha_star", 
      coef_name=names(coef_value),  
      coef=coef_value, 
      se=se_value,
      t=t,
      lci=ci_value[,1],
      uci=ci_value[,2],
      class="boot",
      row.names=NULL
    )
    
    # Combine summaries for current iteration/sim_number, then append to all regressions 
    out <- summary(list(V_Yhuman, V_Yllm)) %>%
      bind_rows(coef_alpha_star) %>% 
      mutate(sim_number=i, .before=1) 
    return(out)
  }
  
  # On all 10K bills, 
  # (i) regress V ~ Yhuman
  V_Yhuman <- simUtils::robust(lm(V ~ Yhuman + 0, data_x), "10k_V_Yhuman")
  
  # (ii) regress V ~ Yllm
  V_Yllm <- simUtils::robust(lm(V ~ Yllm + 0, data_x), "10k_V_Yllm")
  
  # Set seed to combination_id for reproducibility 
  set.seed(combination$combination_id)
  simulations <- bind_rows(parallel::mclapply(1:N, sim_loop, mc.cores = n_cores))
  
  # Add metadata from the combination to all simulations
  regressions <- bind_rows(
    summary(list(V_Yhuman, V_Yllm)), # log all regressions, starting with summary.V_Yhuman, and summary.V_Yllm
    simulations
  ) %>%
    merge(combination, ., all=TRUE)
  
  dir.create(rhs_rds_dir, showWarnings=FALSE, recursive = TRUE)
  if (combination$model %in% c("gpt-5-mini", "gpt-5-nano"))
    path_regressions <- file.path(rhs_rds_dir, sprintf("combination1%04d.rds", combination$combination_id))
  else
    path_regressions <- file.path(rhs_rds_dir, sprintf("combination0%04d.rds", combination$combination_id))
  
  saveRDS(regressions, file=path_regressions)
  cat(sprintf("Saved %s\n", path_regressions))
}
