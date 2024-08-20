# (1) Generic Functions

# (1.1) Recode using provided list of topics, converting the non-included topics to "Other"
recode_topics <- function(x, topics){
  x_recoded <- addNA(factor(x, levels=topics))  # Recode factor levels, including NA
  n <- nlevels(x_recoded)
  if (is.na(levels(x_recoded)[n]))
    levels(x_recoded)[n] = "Other" # Label NA levels as "Other"
  return(x_recoded)
}

# (1.2) Generate a summary of the regression model using robust standard errors
summary_robust <- function(model, name.regression, alpha=0.05, z.score=TRUE){
  coef.values <- coef(model)
  
  # Simplify coefficient names
  coef.names <- gsub("Yhuman|Yllm|Ytilde", "Y",  names(coef.values))
  
  # Compute robust SEs
  robust.model <- coeftest(model, vcov=vcovHC(model, type = "HC1"))
  se <- robust.model[,"Std. Error"]
  t_stat <- robust.model[,"t value"]
  
  # Compute CI use z-score or t-score
  probs <- c(alpha/2, 1-alpha/2)
  if (z.score) 
    score <- qnorm(probs) 
  else # ci = unname(coefci(model, level=1-alpha, vcov=vcovHC(model, type = "HC1")))
    score = qt(probs, df = model$df)
  ci = matrix(se, ncol=1) %*% matrix(score, ncol=2) + coef.values
  colnames(ci) = sprintf("%.1f%%", probs*100)
  
  return(list(data.frame(
    regression=name.regression, coef_name=coef.names, coef=coef.values, 
    se=se, t_stat=t_stat, lci=ci[,1], uci=ci[,2], row.names=NULL)))
}

# (1.3) Generate a summary of the bootstrap results, including standard errors and confidence intervals
summary_boot = function(coef.values, boot.coef.values, name.regression, alpha=0.05){
  
  # Simplify coefficient names
  coef.names <- gsub("Yhuman|Yllm|Ytilde", "Y",  names(coef.values))
  
  # Calculate standard errors from bootstrap samples
  se <- apply(boot.coef.values, 2, sd)
  t_stat <- coef.values/se
  
  # Calculate CIs from bootstrap samples using the percentile method
  probs <- c(alpha/2, 1-alpha/2)
  ci_transposed <- apply(boot.coef.values, 2, FUN=quantile, probs=probs)
  ci <- t(ci_transposed)
  colnames(ci) <- sprintf("%.1f%%", probs*100)
  
  return(list(data.frame(
    regression=name.regression, coef_name=coef.names, coef=coef.values, 
    se=se, t_stat=t_stat, lci=ci[,1], uci=ci[,2], row.names = NULL)))
}

# (2) LHS regression functions
# (2.1) Function to run the regression (Ytilde ~ V, data=test)
fun.test_Ytilde_V <- function(train, test, return.intermediate_regressions=FALSE){
  # if no Bayesian bootstrap weights are provided, don't perform weighted LS by setting w=1
  if ( (is.null(train$w)) | (is.null(test$w)) ){
    train$w <- 1 
    test$w <- 1
  }
  
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

# (2.2) Run LHS regressions based on the specified combination.
fun.lhs_regressions <- function(combination, boot=c("nonparametric", "bayesian"), rds_dir=NULL) {
  boot <- match.arg(boot)
  
  # Reformat and filter the local data from global DATA based on the current combination
  data <- DATA %>% 
    filter(Model==combination$model, 
           Prompt==combination$prompt) %>%
    mutate(V = .[[combination$variable]],
           Yhuman = as.integer(Yhuman == combination$major_topic),
           Yllm = as.integer(Yllm == combination$major_topic))
  
  # On all 10K bills:
  # (i) regress Yhuman ~ V
  Yhuman_V <- lm(Yhuman ~ V, data=data)
  summary.Yhuman_V <- summary_robust(Yhuman_V, name="10k_Yhuman_V")
  
  # (ii) regress Yllm ~ V
  Yllm_V <- lm(Yllm ~ V, data=data)
  summary.Yllm_V <- summary_robust(Yllm_V, name="10k_Yllm_V")
  
  # Initialize a data frame to log all regressions, starting with summary.Yhuman_V, and summary.Yllm_V
  regressions <- bind_rows(summary.Yhuman_V, summary.Yllm_V)
  
  # Set seed to combination_id for reproducibility 
  set.seed(combination$combination_id)
  
  # N simulations (outer loop)
  for (i in (1:combination$N)){ 
    # Randomly draw n_samples observations with replacement
    data_sample <- data[sample(x=nrow(data), size=combination$n_samples, replace=TRUE), ]
    
    # On data_sample, regress Yllm ~ V
    Yllm_V <- lm(Yllm ~ V, data=data_sample)
    summary.Yllm_V <- summary_robust(Yllm_V, name="5k_Yllm_V")
    
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
  
  # If rds_dir is provided, results will be saved as an RDS file; otherwise, they will be returned as a data.frame.
  if (is.null(rds_dir)){
    return (regressions)
  } else {
    path_regressions <- file.path(rds_dir, sprintf("combination%05d.rds", combination$combination_id))
    saveRDS(regressions, file=path_regressions)
    return(data.frame(path=path_regressions))
  }
}

# (3) RHS regression functions
# (3.1) Function to run the regression (Vtilde ~ Ytilde, data=test)
fun.test_Vtilde_Ytilde <- function(train, test, return.intermediate_regressions=FALSE){
  
  # if no Bayesian bootstrap weights are provided, don't perform weighted LS by setting w=1
  if ( (is.null(train$w)) | (is.null(test$w)) ){
    train$w = 1
    test$w = 1
  }
  
  # Initialize a list to store summaries of intermediate regressions, e.g., error ~ V
  regressions <- list()
  
  # (i) Train data
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
  
  # (ii) Test data
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
  
  return(list(coef.train_nu_Yllm=delta_nu_Yllm, 
              coef.test_Vtilde_Ytilde=coef.test_Vtilde_Ytilde, 
              regressions=regressions))
}

# (3.2) Run RHS regressions based on the specified combination.
fun.rhs_regressions <- function(combination, rds_dir=NULL, boot=c("bayesian", "nonparametric"), all_reg=TRUE){
  boot <- match.arg(boot)
  
  # Reformat and filter the local data from global DATA based on the current combination
  data <- DATA %>% 
    filter(Model==combination$model, 
           Prompt==combination$prompt) %>%
    mutate(V = .[[combination$variable]])
  
  # On all 10K bills, 
  # (i) regress V ~ Yhuman
  V_Yhuman = lm(V ~ Yhuman + 0, data=data)
  summary.V_Yhuman = summary_robust(V_Yhuman, name="10k_V_Yhuman")
  
  # (ii) regress V ~ Yllm
  V_Yllm <- lm(V ~ Yllm + 0, data=data)
  summary.V_Yllm <- summary_robust(V_Yllm, name="10k_V_Yllm")
  
  # Initialize a data frame to log all regressions, starting with summary.V_Yhuman, and summary.V_Yllm
  regressions <- bind_rows(summary.V_Yhuman, summary.V_Yllm)
  
  # Set seed to combination_id for reproducibility 
  set.seed(combination$combination_id)
  
  # N simulations (outer loop)
  for (i in (1:combination$N)){ 
    
    # Randomly draw n_samples observations with replacement
    data_sample <- data[sample(x=nrow(data), size=combination$n_samples, replace=TRUE), ]
    
    # Split data into train and test sets based on the predefined train_proportion. Since data_sample is already a random sample, we don't need to randomize again.
    train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
    train <- data_sample[train_idx, ]
    
    rank_Yhuman <- Matrix::rankMatrix(model.matrix(~ Yhuman + 0, data=train))[1]
    rank_Yllm <- Matrix::rankMatrix(model.matrix(~ Yllm + 0, data=train))[1]
    while ((rank_Yhuman<6) | (rank_Yllm<6)){
      if (rank_Yhuman<6)
        print(sprintf("Combination ID: %d, sim_number %d: Redraw data_sample because rank(Yhuman)=%d<6.", combination$combination_id, i, rank_Yhuman))
      else
        print(sprintf("Combination ID: %d, sim_number %d: Redraw data_sample because rank(Yllm)=%d<6.", combination$combination_id, i, rank_Yllm))
      
      data_sample <- data[sample(x=nrow(data), size=combination$n_samples, replace=TRUE), ]
      train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
      train <- data_sample[train_idx, ]
      
      rank_Yhuman <- Matrix::rankMatrix(model.matrix(~ Yhuman + 0, data=train))[1]
      rank_Yllm <- Matrix::rankMatrix(model.matrix(~ Yllm + 0, data=train))[1]
    }
    test <- data_sample[-train_idx, ] %>% select(!Yhuman)
    
    # On data_sample, regress Yllm ~ V
    V_Yllm = lm(V ~ Yllm + 0, data=data_sample)
    summary.V_Yllm = summary_robust(V_Yllm, name="5k_V_Yllm")
    
    # (i) On train data, regress Yhuman ~ V (beta). Report robust standard errors
    # This is done and recorded in fun.test_Vtilde_Ytilde().
    
    # (ii) Using train and test data, regress V_tilde ~ Ytilde, see fun.test_Vtilde_Ytilde() for more details
    test_Vtilde_Ytilde <- fun.test_Vtilde_Ytilde(train=train, test=test, return=TRUE)
    
    coef.train_nu_Yllm <- test_Vtilde_Ytilde$coef.train_nu_Yllm # delta_{nu, \hat{Y}}
    coef.test_Vtilde_Ytilde <- test_Vtilde_Ytilde$coef.test_Vtilde_Ytilde
    summary.intermediate_regressions <- test_Vtilde_Ytilde$regressions
    
    # Perform bootstrap on test_Ytilde_V to calculate standard errors and confidence intervals
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
  
  # If rds_dir is provided, results will be saved as an RDS file; otherwise, they will be returned as a data.frame.
  if (is.null(rds_dir)){
    return(regressions)
  } else {
    path_regressions <- file.path(rds_dir, sprintf("combination%05d.rds", combination$combination_id))
    saveRDS(regressions, file=path_regressions)
    return(data.frame(path=path_regressions))
  }
}
