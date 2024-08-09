# title: "Simulations"
# date: "July 31, 2024"
# output: html_document
# This code is based on https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/egami_et_al/code/LLM_errors.R

repo_dir = "~/Documents/LanguageModel_Labels/congressional_bills"

require(zoo, quietly=TRUE, warn.conflicts=FALSE)
require(dplyr, quietly=TRUE, warn.conflicts=FALSE)
require(sandwich, quietly=TRUE, warn.conflicts=FALSE)
require(lmtest, quietly=TRUE, warn.conflicts=FALSE)
require(furrr, quietly=TRUE, warn.conflicts=FALSE)
require(progressr, quietly=TRUE, warn.conflicts=FALSE)

n_cores = 8
debug = TRUE
debug.n = 20

n_samples = 5000 
sel_topics = c(3, 14, 15, 19, 20) # these are the most common major topics based on Major/Yhuman column (not MajorLLM/Yllm)

# To take input from command line
args = commandArgs(trailingOnly = TRUE)
if (length(args)>0){
  n_cores = as.numeric(args[1])
  debug = FALSE
} 
if (length(args)>1){
  debug = "debug"==args[2]
  debug.n = as.numeric(args[3])
}

# Check if we have enough cores
if (n_cores > parallelly::availableCores())
  n_cores = parallelly::availableCores()
plan(multisession, workers = n_cores)
cat(sprintf("n_cores = %d\n", n_cores))

# Set up directories to store results
simulation_dir = file.path(repo_dir, "04_simulation")
combinations_path = file.path(simulation_dir, "rhs_combinations.csv")
combinations = read.csv(combinations_path)

rds_dir = file.path(simulation_dir, "rhs_rds")
dir.create(rds_dir, showWarnings=FALSE)
rds_paths_completed = list.files(rds_dir, pattern = "*.rds")
if (length(rds_paths_completed) != 0){ 
  combination_id_completed = as.numeric(gsub("combination|\\.rds", "", rds_paths_completed))
  combinations = combinations %>% filter(!(id %in% combination_id_completed))
  cat(sprintf("Combination ID = %d has already been completed. Skipping.\n", combination_id_completed))
}
if (nrow(combinations)==0)
  stop("Current directory contains all rds files")
cat(sprintf("Total number of combinations = %d\n", nrow(combinations)))

if (debug){
  cat("Debug mode: choose first %d combinations", debug.n)
  combinations = combinations[1:debug.n, ]
  rds_dir = sprintf("%s_debug", rds_dir)
  dir.create(rds_dir, showWarnings=FALSE)
}
cat("Rds/results dir: %s", rds_dir)

## Restructure data a bit
recode_topics = function(x, topics){
  x_recoded = addNA(factor(x, levels=topics))
  n = nlevels(x_recoded)
  if (is.na(levels(x_recoded)[n]))
    levels(x_recoded)[n] = "Other" # recode NA levels as "Other"
  return(x_recoded)
}

data = read.csv(file.path(repo_dir, "02_llm/bills_prompts_responses_10000.csv")) %>% 
  mutate(
    Senate = as.integer(Chamber == "Senate"),
    Democrat = as.integer(Party == "Democrat"),
    Prompt = PromptingStrategyID,
    Yhuman = recode_topics(.$Major, topics=sel_topics),
    Yllm = recode_topics(.$MajorLLM, topics=sel_topics)
  ) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Yhuman, Yllm)

## Functions
summary_robust = function(model, name.regression, alpha=0.05, z.score=TRUE){
  coef.values = coef(model)
  coef.names = gsub("Yhuman|Yllm|Ytilde", "",  names(coef.values))
  
  robust.model = coeftest(model, vcov=vcovHC(model, type = "HC1"))
  se = robust.model[,"Std. Error"]
  t_stat = robust.model[,"t value"]
  
  probs = c(alpha/2, 1-alpha/2)
  if (z.score) 
    score = qnorm(probs)
  else # t-score # ci = unname(coefci(model, level=1-alpha, vcov=vcovHC(model, type = "HC1")))
    score = qt(probs, df = model$df)
  ci = matrix(se, ncol=1) %*% matrix(score, ncol=2) + coef.values
  colnames(ci) = sprintf("%.1f%%", probs*100)
  
  return(list(data.frame(
    regression=name.regression, coef_name=coef.names, coef=coef.values, 
    se=se, t_stat=t_stat, lci=ci[,1], uci=ci[,2], row.names=NULL)))
}

summary_boot = function(coef.values, boot.coef.values, name.regression, alpha=0.05, method.ci=c("percentile")){
  coef.names = gsub("Yhuman|Yllm|Ytilde", "",  names(coef.values))
  se = apply(boot.coef.values, 2, sd)
  t_stat=coef.values/se
  
  method.ci = match.arg(method.ci)
  probs = c(alpha/2, 1-alpha/2)
  ci_transposed = apply(boot.coef.values, 2, FUN=quantile, probs=probs)
  ci = t(ci_transposed)
  colnames(ci) = sprintf("%.1f%%", probs*100)
  
  return(list(data.frame(
    regression=name.regression, coef_name=coef.names, coef=coef.values, 
    se=se, t_stat=t_stat, lci=ci[,1], uci=ci[,2], row.names = NULL)))
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
  train_V_Yhuman = lm(V ~ Yhuman + 0, weights=w, data=train)
  beta = coef(train_V_Yhuman) 
  
  # delta_{V, \hat{Y}}
  train_V_Yllm = lm(V ~ Yllm + 0, weights=w, data=train) 
  delta_V_Yllm = coef(train_V_Yllm)
  
  # delta_{Y, \hat{Y}}
  Yhuman = model.matrix(~ Yhuman + 0, data=train)
  formula = sprintf("cbind(%s) ~ Yllm + 0", paste(colnames(Yhuman), collapse=", "))
  train_Yhuman_Yllm = lm(formula, weights = w, data=cbind(train, Yhuman)) 
  delta_Yhuman_Yllm = coef(train_Yhuman_Yllm) # 20*20, Yllm * Yhuman
  
  # delta_{nu, \hat{Y}} = delta_{V, \hat{Y}} - delta_{Y, \hat{Y}} beta
  delta_nu_Yllm = delta_V_Yllm - as.vector(delta_Yhuman_Yllm %*% beta)
  
  # Test data
  Yllm = model.matrix(~ Yllm + 0, data=test)
  
  # Ytilde: predicted Yhuman
  Ytilde = Yllm %*% delta_Yhuman_Yllm
  colnames(Ytilde) = sub("human","tilde", colnames(Ytilde))
  
  # V_tilde
  test$V_tilde = test$V - Yllm %*% delta_nu_Yllm 
  
  # Regress and get coef.test_Vtilde_Ytilde
  formula = sprintf("V_tilde ~ %s + 0", paste(colnames(Ytilde), collapse=" + "))
  test_Vtilde_Ytilde = lm(formula, weights=w, data=cbind(test, Ytilde))
  coef.test_Vtilde_Ytilde = coef(test_Vtilde_Ytilde)
  return(list(coef.train_nu_Yllm=delta_nu_Yllm, coef.test_Vtilde_Ytilde=coef.test_Vtilde_Ytilde))
}

outer_loop_function = function(data, combination, save.rds=TRUE){
  set.seed(combination$combination_id)
  
  data = data %>% 
    filter(Model==combination$model, 
           Prompt==combination$prompt) %>%
    mutate(V = .[[combination$variable]])
  
  levels_coef = levels(data$Yhuman)
  
  # Using human-labeled major_topic topics on all 10K bills
  # summary.V_Yhuman is the same across all simulation runs, and will have a sim_number = NA
  V_Yhuman = lm(V ~ Yhuman + 0, data=data)
  summary.V_Yhuman = summary_robust(V_Yhuman, name="V_Yhuman")
  
  # regression_df is a data frame to log all regressions, we start by adding summary.V_Yhuman once.
  regression_df = summary.V_Yhuman 
  
  for (i in (1:combination$N)){ # outer loop
    regression_list_i = list() # list of regressions in the ith simulation 
    
    # We randomly draw 5000 observations with replacement.
    data_sample = data[sample(x=nrow(data), size=combination$n_samples, replace=TRUE), ]
    
    # On the 5000 observations, we calculate V_Yllm
    V_Yllm = lm(V ~ Yllm + 0, data=data_sample)
    summary.V_Yllm = summary_robust(V_Yllm, name="V_Yllm")
    
    # On the 5000 observations, we split the data into a train/test split. 
    # Note: Since it's already a random sample, we don't do it using the sample function
    train_idx = 1:(nrow(data_sample) * combination$train_proportion)
    train = data_sample[train_idx, ]
    test = data_sample[-train_idx, ] %>% select(!Yhuman)
    
    # beta (this is also train_V_Yhuman that we need to log)
    train_V_Yhuman = lm(V ~ Yhuman + 0, data=train)
    summary.train_V_Yhuman = summary_robust(train_V_Yhuman, name="train_V_Yhuman")
    
    # delta_{V, \hat{Y}}
    train_V_Yllm = lm(V ~ Yllm + 0, data=train) 
    summary.train_V_Yllm = summary_robust(train_V_Yllm, name="train_V_Yllm")
    
    # delta_{Y, \hat{Y}}
    train_Yhuman = model.matrix(~ Yhuman + 0, data=train)
    # to store the model parameter, we run the regression one dependent variable at a time instead of using cbind()
    train_Yhuman.X_Yllm_list = list()
    for (level in levels_coef){
      formula = sprintf("%s ~ Yllm + 0", sprintf("Yhuman%s", level))
      train_Yhuman.X_Yllm = lm(formula, data=cbind(train, train_Yhuman)) 
      train_Yhuman.X_Yllm = summary_robust(train_Yhuman.X_Yllm, name=sprintf("train_Yhuman.%s_Yllm", level))
      train_Yhuman.X_Yllm_list = append(train_Yhuman.X_Yllm_list, train_Yhuman.X_Yllm)
    }
    
    # delta_{nu, \hat{Y}} & coef of V_tilde ~ Ytilde
    out = get_debiased_coefs(train=train, test=test)
    coef.train_nu_Yllm = out$coef.train_nu_Yllm # delta_{nu, \hat{Y}}
    coef.test_Vtilde_Ytilde = out$coef.test_Vtilde_Ytilde # coef of V_tilde ~ Ytilde
    
    # We then begin the bootstrap (inner loop), this is because nu_Yllm_train and Vtilde_Ytilde_test are a function of predicted coefs and so we can't use se and ci from the lm model.
    boot.coef.train_nu_Yllm = matrix(NA, nrow=combination$B, ncol=length(levels_coef), dimnames=list(NULL, levels_coef))
    boot.coef.test_Vtilde_Ytilde = matrix(NA, nrow=combination$B, ncol=length(levels_coef), dimnames=list(NULL, levels_coef))
    for (b in 1:combination$B){
      boot.coefs = get_debiased_coefs(train=train, test=test, boot="bayesian")
      boot.coef.train_nu_Yllm[b,] = boot.coefs$coef.train_nu_Yllm
      boot.coef.test_Vtilde_Ytilde[b,] = boot.coefs$coef.test_Vtilde_Ytilde
    }
    
    # We use bootstrap samples to calculate se and ci
    summary.train_nu_Yllm = summary_boot(coef.train_nu_Yllm, boot.coef.train_nu_Yllm, name="train_nu_Yllm")
    test_Vtilde_Ytilde = summary_boot(coef.test_Vtilde_Ytilde, boot.coef.test_Vtilde_Ytilde, name="test_Vtilde_Ytilde")
    
    regression_df_i = bind_rows(
      summary.V_Yllm, summary.train_V_Yhuman, test_Vtilde_Ytilde, # regressions that we report, 
      summary.train_V_Yllm, train_Yhuman.X_Yllm_list, summary.train_nu_Yllm # other regressions in case we need them
      ) %>% 
      mutate(sim_number=i)
    
    regression_df = bind_rows(regression_df, regression_df_i)
  }
  
  regression_df = regression_df %>% 
    relocate(sim_number, .before = regression) %>%
    merge(combination, ., all=TRUE)
  
  if (save.rds){
    saveRDS(regression_df, file=file.path(rds_dir, sprintf("combination%05d.rds", combination$combination_id)))
    return(combination$combination_id)
  } else {
    return(regression_df)
  }
}


# Estimate run time
combination = combinations[1,]
N_original = combination$N
combination$N = 1

start_time = Sys.time()
regressions_temp = outer_loop_function(
  data = data, 
  combination = combination,
  save.rds = FALSE)
end_time = Sys.time()

duration1 = as.numeric(end_time - start_time, unit="hours")
duration = duration1 * N_original * nrow(combinations) / n_cores
cat(sprintf("Expected run time = %.2f hours assuming N=%d and B=%d\n", duration, N_original, combination$B))

# Run simulations
set.seed(123)
regressions = future_map(
  .options = furrr_options(seed=TRUE), # we also reset the seed inside .f using the combination index, e.g., set.seed(1)
  .x = 1:nrow(combinations),
  .f = function(x) {
    out = outer_loop_function(
      data=data,
      combination=combinations[x,])
    return(out)
    },
  .progress=FALSE)
