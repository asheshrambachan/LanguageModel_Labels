# title: "Simulations"
# date: "July 31, 2024"
# output: html_document
# This code is based on https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/egami_et_al/code/LLM_errors.R

args = commandArgs(trailingOnly = TRUE)
if (length(args)>0){
  N = as.numeric(args[1])
  B = as.numeric(args[2])
  n_cores = as.numeric(args[3])
} else {
  N = 10
  B = 100
  n_cores = 10
}
n_samples = 5000 # 5000 
sel_topics = c(3, 14, 15, 19, 20)
train_proportion = c(0.1, 0.25, 0.5)
variable = c("Senate", "Democrat", "DW1")
debug = TRUE

require(zoo, quietly=TRUE, warn.conflicts=FALSE)
require(dplyr, quietly=TRUE, warn.conflicts=FALSE)
require(sandwich, quietly=TRUE, warn.conflicts=FALSE)
require(lmtest, quietly=TRUE, warn.conflicts=FALSE)
require(furrr, quietly=TRUE, warn.conflicts=FALSE)
require(progressr, quietly=TRUE, warn.conflicts=FALSE)

## Functions
recode_most_common = function(x, n_topics=5){
  n_levels = n_topics + 1
  if (nlevels(factor(x)) > n_levels) {
    labels_curr = order(table(x), decreasing=TRUE)[1:(n_levels-1)]
    labels_curr = sort(labels_curr)
    x_recoded = addNA(factor(x, levels=labels_curr))
    levels(x_recoded)[n_levels] = "Other" # recode NA levels as "other"
  } else 
    x_recoded = factor(x)
  return(x_recoded)
}

recode_topics = function(x, topics=c(3, 14, 15, 19, 20)){
  x_recoded = addNA(factor(x, levels=topics))
  n = nlevels(x_recoded)
  if (is.na(levels(x_recoded)[n]))
    levels(x_recoded)[n] = "Other" # recode NA levels as "other"
  return(x_recoded)
}

se_robust = function(model){
  model_output = coeftest(model, vcov=vcovHC(model, type = "HC1"))
  return(model_output[,"Std. Error"])
}

ci_robust = function(model, alpha=0.05, use_z_score=TRUE){
  probs = c(alpha/2, 1-alpha/2)
  if (use_z_score){
    score = qnorm(probs)
    ci = matrix(se_robust(model), ncol=1) %*% matrix(score, ncol=2) + coef(model)
  }
  else { # t-score
    # score = qt(probs, df = model$df)
    # ci = matrix(se_robust(model), ncol=1) %*% matrix(score, ncol=2) + coef(model)
    ci = unname(coefci(model, level=1-alpha, vcov=vcovHC(model, type = "HC1")))
  }
  colnames(ci) = sprintf("%.1f%%", probs*100)
  return(ci)
}

se_boot = function(samples_boot) apply(samples_boot, 2, sd)

ci_boot = function(samples_boot, alpha=0.05, method=c("percentile")) {
  method = match.arg(method)
  ci_transposed = apply(samples_boot, 2, FUN=quantile, probs=c(alpha/2, 1-alpha/2))
  ci = t(ci_transposed)
  return(ci)
}

get_debiased_coefs = function(train, test, boot=c("none", "nonparametric", "bayesian")){
  boot = match.arg(boot)
  if (boot=="nonparametric"){
    train$w = 1
    test$w = 1
    train = train[sample(x=nrow(train), replace=TRUE), ]
    test = test[sample(x=nrow(test), replace=TRUE), ]
  } else if (boot=="bayesian") {
    w_train = rgamma(nrow(train), shape=1, scale=1) # rexp(n=nrow(train), rate=1)
    train$w = w_train/sum(w_train)
    w_test = rgamma(nrow(test), shape=1, scale=1)
    test$w = w_test/sum(w_test)
  } else {
    train$w = 1
    test$w = 1
  }
  
  # Train data
  # beta 
  model_V_Yhuman = lm(V ~ Yhuman + 0, weights=w, data=train)
  beta = coef(model_V_Yhuman) 
  
  # delta_{V, \hat{Y}}
  model_V_Yllm = lm(V ~ Yllm + 0, weights=w, data=train) 
  delta_V_Yllm = coef(model_V_Yllm)
  
  # delta_{Y, \hat{Y}}
  Yhuman = model.matrix(~ Yhuman + 0, data=train)
  formula = sprintf("cbind(%s) ~ Yllm + 0", paste(colnames(Yhuman), collapse=", "))
  model_Yhuman_Yllm = lm(formula, weights = w, data=cbind(train, Yhuman)) 
  delta_Yhuman_Yllm = coef(model_Yhuman_Yllm) # 20*20, Yllm * Yhuman
  
  # delta_{nu, \hat{Y}} = delta_{V, \hat{Y}} - delta_{Y, \hat{Y}} beta
  delta_nu_Yllm = delta_V_Yllm - as.vector(delta_Yhuman_Yllm %*% beta)
  
  # Test data
  # Ytilde (predicted Yhuman)
  Yllm = model.matrix(~ Yllm + 0, data=test)
  Ytilde = Yllm %*% delta_Yhuman_Yllm
  colnames(Ytilde) = sub("human","tilde", colnames(Ytilde))
  
  # V_tilde
  test$V_tilde = test$V - Yllm %*% delta_nu_Yllm 
  
  # Regress and get coef
  formula = sprintf("V_tilde ~ %s + 0", paste(colnames(Ytilde), collapse=" + "))
  model_Vtilde_Ytilde = lm(formula, weights=w, data=cbind(test, Ytilde))
  Vtilde_Ytilde_coef = coef(model_Vtilde_Ytilde)
  return(list(delta_nu_Yllm=delta_nu_Yllm, Vtilde_Ytilde_coef=Vtilde_Ytilde_coef))
}

outer_loop_function = function(data, combination, N, B, n_samples){
  set.seed(combination$id)
  variable = combination$variable
  model = combination$model 
  prompt = combination$prompt
  train_proportion = combination$train_proportion
  
  coef_name = levels(data$Yhuman)
  
  regression = c("V_Yhuman", "V_Yllm", "train_V_Yhuman", "train_V_Yllm", 
                 "train_nu_Yllm", "test_Vtilde_Ytilde", 
                 sprintf("train_Yhuman.%s_Yllm", coef_name))
  
  expand.grid(regression=regression, sim_number=1:N, stringsAsFactors=FALSE)
  
  n_coef = nlevels(data$Yhuman)
  
  
  betas = as.data.frame(
    "variable" = variable, 
    "model" = model, 
    "prompt" = prompt, 
    "train_proportion" = train_proportion, 
    "sim_number" = 1:N)

  for (r in regression){
    betas$coef[[model2log]] = matrix(NA, nrow=N, ncol=length(coef_name), dimnames=list(NULL, coef_name))
    betas$se[[model2log]] = matrix(NA, nrow=N, ncol=length(coef_name), dimnames=list(NULL, coef_name))
    betas$lci[[model2log]] = matrix(NA, nrow=N, ncol=length(coef_name), dimnames=list(NULL, coef_name))
    betas$uci[[model2log]] = matrix(NA, nrow=N, ncol=length(coef_name), dimnames=list(NULL, coef_name))
  }
  
  data = data %>% 
    filter(Model==model, 
           Prompt==prompt) %>%
    mutate(V = .[[variable]])
  
  # Using human-labeled major_topic topics on all 10K bills
  model_V_Yhuman = lm(V ~ Yhuman + 0, data=data)
  betas$coef$V_Yhuman[1:N,] = matrix(coef(model_V_Yhuman), nrow=N, ncol=n_coef, byrow=TRUE)
  betas$se$V_Yhuman[1:N,] = matrix(se_robust(model_V_Yhuman), nrow=N, ncol=n_coef, byrow=TRUE)
  betas$lci$V_Yhuman[1:N,] = matrix(ci_robust(model_V_Yhuman, alpha=0.05, use_z_score=TRUE)[,1], nrow=N, ncol=n_coef, byrow=TRUE)
  betas$uci$V_Yhuman[1:N,] = matrix(ci_robust(model_V_Yhuman, alpha=0.05, use_z_score=TRUE)[,2], nrow=N, ncol=n_coef, byrow=TRUE)
  
  for (i in (1:N)){ # outer loop
    # We randomly draw 5000 observations with replacement.
    data_sample = data[sample(x=nrow(data), size=n_samples, replace=TRUE) ,]
    
    # On the 5000 observations, we calculate model_V_Yllm
    model_V_Yllm = lm(V ~ Yllm + 0, data=data_sample) # TODO: confirm no intercept
    betas$coef$V_Yllm[i,] = coef(model_V_Yllm)
    betas$se$V_Yllm[i,] = se_robust(model_V_Yllm)
    betas$lci$V_Yllm[i,] = ci_robust(model_V_Yllm, alpha=0.05, use_z_score=TRUE)[,1]
    betas$uci$V_Yllm[i,] = ci_robust(model_V_Yllm, alpha=0.05, use_z_score=TRUE)[,2]
    
    # On the 5000 observations, we split the data into a train/test split. Since it's already a random sample, we don't do it using the sample function
    train_idx = 1:(n_samples * train_proportion)
    train = data_sample[train_idx, ]
    test = data_sample[-train_idx, ]
    test$Yhuman = NULL
    
    # beta (this is also model_train_V_Yhuman)
    model_train_V_Yhuman = lm(V ~ Yhuman + 0, data=train)
    betas$coef$train_V_Yhuman[i,] = coef(model_train_V_Yhuman)
    betas$se$train_V_Yhuman[i,] = se_robust(model_train_V_Yhuman)
    betas$lci$train_V_Yhuman[i,] = ci_robust(model_train_V_Yhuman, alpha=0.05, use_z_score=TRUE)[,1] 
    betas$uci$train_V_Yhuman[i,] = ci_robust(model_train_V_Yhuman, alpha=0.05, use_z_score=TRUE)[,2] 
    
    # delta_{V, \hat{Y}}
    model_train_V_Yllm = lm(V ~ Yllm + 0, data=train) 
    betas$coef$train_V_Yllm[i,] = coef(model_train_V_Yllm)
    betas$se$train_V_Yllm[i,] = se_robust(model_train_V_Yllm)
    betas$lci$train_V_Yllm[i,] = ci_robust(model_train_V_Yllm, alpha=0.05, use_z_score=TRUE)[,1] 
    betas$uci$train_V_Yllm[i,] = ci_robust(model_train_V_Yllm, alpha=0.05, use_z_score=TRUE)[,2] 
    
    # delta_{Y, \hat{Y}}
    train_Yhuman = model.matrix(~ Yhuman + 0, data=train)
    formula_dep = paste(colnames(train_Yhuman), collapse=", ")
    formula = sprintf("cbind(%s) ~ Yllm + 0", formula_dep)
    model_train_Yhuman_Yllm = lm(formula, data=cbind(train, train_Yhuman))
    delta_Yhuman_Yllm = coef(model_train_Yhuman_Yllm)
    
    # to store the model parameter, we redo the regression, but one dependent variable at a time instead of using cbind()
    for (level in coef_name){
      formula = sprintf("%s ~ Yllm + 0", sprintf("Yhuman%s", level))
      model_train_Yhuman.X_Yllm = lm(formula, data=cbind(train, train_Yhuman)) 
      
      model_name = sprintf("train_Yhuman.%s_Yllm", level)
      betas$coef[[model_name]][i,] = coef(model_train_Yhuman.X_Yllm)
      betas$se[[model_name]][i,] = se_robust(model_train_Yhuman.X_Yllm)
      betas$lci[[model_name]][i,] = ci_robust(model_train_Yhuman.X_Yllm, alpha=0.05, use_z_score=TRUE)[,1]
      betas$uci[[model_name]][i,] = ci_robust(model_train_Yhuman.X_Yllm, alpha=0.05, use_z_score=TRUE)[,2]
    }
    
    
    out = get_debiased_coefs(train=train, test=test)
    betas$coef$train_nu_Yllm[i,] = out$delta_nu_Yllm # delta_{nu, \hat{Y}}
    betas$coef$test_Vtilde_Ytilde[i,] = out$Vtilde_Ytilde_coef # coef of V_tilde ~ Ytilde
    
    # We then begin the bootstrap (inner loop), this is because nu_Yllm_train and Vtilde_Ytilde_test are a function of predicted coefs and so we can't use se and ci from the lm model.
    train_nu_Yllm_coef_boot = matrix(NA, nrow=B, ncol=n_coef, dimnames=list(NULL, coef_name))
    test_Vtilde_Ytilde_coef_boot = matrix(NA, nrow=B, ncol=n_coef, dimnames=list(NULL, coef_name))
    for (b in 1:B){
      out_boot = get_debiased_coefs(train=train, test=test, boot="bayesian")
      train_nu_Yllm_coef_boot[b,] = out_boot$delta_nu_Yllm
      test_Vtilde_Ytilde_coef_boot[b,] = out_boot$Vtilde_Ytilde_coef
    }
    
    # We use bootstrap samples to calculate se and ci
    betas$se$train_nu_Yllm[i,] = se_boot(train_nu_Yllm_coef_boot)
    betas$lci$train_nu_Yllm[i,] = ci_boot(train_nu_Yllm_coef_boot, alpha=0.05, method="percentile")[,1] # lower ci
    betas$uci$train_nu_Yllm[i,] = ci_boot(train_nu_Yllm_coef_boot, alpha=0.05, method="percentile")[,2] # upper ci
    
    betas$se$test_Vtilde_Ytilde[i,] = se_boot(test_Vtilde_Ytilde_coef_boot)
    betas$lci$test_Vtilde_Ytilde[i,] = ci_boot(test_Vtilde_Ytilde_coef_boot, alpha=0.05, method="percentile")[,1] # lower ci
    betas$uci$test_Vtilde_Ytilde[i,] = ci_boot(test_Vtilde_Ytilde_coef_boot, alpha=0.05, method="percentile")[,2] # upper ci
  }
  
  betas_df = cbind(combination_id=combination$id, as.data.frame(betas))
  saveRDS(betas_df, file=file.path(rds_dir, sprintf("combination%05d.rds", combination$id)))
  return(betas_df)
}

## Run
repo_dir = "~/Documents/LanguageModel_Labels/congressional_bills"
simulation_dir = file.path(repo_dir, "04_simulation")
setwd(simulation_dir)
rds_dir = file.path(simulation_dir, sprintf("rhs_rds_N%d_B%d", N, B))
dir.create(rds_dir, showWarnings=FALSE)

if (n_cores > parallelly::availableCores())
  n_cores = parallelly::availableCores()
cat(sprintf("N = %d, B = %d, n_cores = %d\n", N, B, n_cores))

data = read.csv(file.path(repo_dir, "02_llm/bills_prompts_responses_10000.csv")) %>% 
  mutate(
    Senate = as.integer(Chamber == "Senate"),
    Democrat = as.integer(Party == "Democrat"),
    Prompt = PromptingStrategyID,
    Yhuman = recode_topics(.$Major, topics=sel_topics),
    Yllm = recode_topics(.$MajorLLM, topics=sel_topics)
    ) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Yhuman, Yllm)

combinations = expand.grid(
  train_proportion = train_proportion, # 10%train 90%test, ...  
  prompt = unique(data$Prompt),
  model = unique(data$Model),
  variable = variable, 
  stringsAsFactors = FALSE
)
combinations = cbind(id = 1:nrow(combinations), combinations)

# check if dir contain completed runs and skip them
if (debug){
  combinations = combinations[1:10,]
} else {
  rds_paths_completed = list.files(rds_dir, pattern = "*.rds")
  if (length(rds_paths_completed) != 0){
    combination_id_completed = as.numeric(gsub("combination|\\.rds", "", rds_paths_completed))
    combinations = combinations %>% filter(!(id %in% combination_id_completed))
    cat(sprintf("Combination ID = %d has already been completed. Skipping.\n", combination_id_completed))
  }
  if (nrow(combinations)==0)
    stop("Current directory contains all rds files")
}
cat(sprintf("Total number of combinations = %d\n", nrow(combinations)))

start_time = Sys.time()
betas_df = outer_loop_function(
  data=data,
  combination=combinations[1,],
  N=1,
  B=B,
  n_samples=n_samples
)
end_time = Sys.time()
duration_N1_combination1 = as.numeric(end_time - start_time, unit="hours")
duration = duration_N1_combination1 * N * nrow(combinations) / n_cores
cat(sprintf("Expected run time = %.2f hours\n", duration))

plan(multisession, workers = n_cores)
set.seed(123)
out_list = future_map(
  .options = furrr_options(seed=TRUE), # we also reset the seed inside .f using the combination index, e.g., set.seed(1)
  .x = 1:nrow(combinations),
  .f = function(x) {
    out = outer_loop_function(
      data=data,
      combination=combinations[x,],
      N=N,
      B=B,
      n_samples=n_samples
    )},
  .progress=FALSE)
