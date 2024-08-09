# title: "Simulations"
# date: "July 31, 2024"
# output: html_document
# This code is based on https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/egami_et_al/code/LLM_errors.R

require(zoo, quietly=TRUE, warn.conflicts=FALSE)
require(dplyr, quietly=TRUE, warn.conflicts=FALSE)
require(sandwich, quietly=TRUE, warn.conflicts=FALSE)
require(lmtest, quietly=TRUE, warn.conflicts=FALSE)
require(furrr, quietly=TRUE, warn.conflicts=FALSE)
require(progressr, quietly=TRUE, warn.conflicts=FALSE)


n_cores = 3 # 8
debug = TRUE
debug.n = 3
# 
# args = commandArgs(trailingOnly = TRUE)
# if (length(args)>0){
#   n_cores = as.numeric(args[1])
#   debug = FALSE
# }
# 
# if (length(args)>1){
#   debug = "debug"==args[2]
#   debug.n = as.numeric(args[3])
# }

if (n_cores > parallelly::availableCores())
  n_cores = parallelly::availableCores()
cat(sprintf("n_cores = %d\n", n_cores))


repo_dir = "~/Documents/LanguageModel_Labels/congressional_bills"
simulation_dir = file.path(repo_dir, "04_simulation")
setwd(simulation_dir)
combinations_path = file.path(simulation_dir, "lhs_combinations.csv")
combinations = read.csv(combinations_path)

rds_dir = file.path(simulation_dir, "lhs_rds") 
dir.create(rds_dir, showWarnings=FALSE)
rds_paths_completed = list.files(rds_dir, pattern = "*.rds")
if (length(rds_paths_completed) != 0){
  combination_id_completed = as.numeric(gsub("combination|\\.rds", "", rds_paths_completed))
  combinations = combinations %>% filter(!(id %in% combination_id_completed))
  cat(sprintf("Combination ID = %d has already been completed. Skipping.\n", combination_id_completed))
  
  if (nrow(combinations)==0)
    stop("Current directory contains all rds files")
}
cat(sprintf("Total number of combinations = %d\n", nrow(combinations)))

if (debug){
  cat(sprintf("Debug mode: choose first %d combinations\n", debug.n))
  combinations = combinations[1:debug.n, ]
  rds_dir = sprintf("%s_debug", rds_dir) 
  dir.create(rds_dir, showWarnings=FALSE)
  if (length(list.files(rds_dir, pattern = "*.rds", full.names=TRUE))>0)
    file.remove(list.files(rds_dir, pattern = "*.rds", full.names=TRUE))
}
cat(sprintf("Rds/results dir: %s\n", rds_dir))


data = read.csv(file.path(repo_dir, "02_llm/bills_prompts_responses_10000.csv")) %>% 
  mutate(
    Senate = as.integer(Chamber == "Senate"),
    Democrat = as.integer(Party == "Democrat"),
    Prompt = PromptingStrategyID) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Major, MajorLLM) 

## Functions
se_robust = function(model){
  model_output = coeftest(model, vcov=vcovHC(model, type = "HC1"))
  return(model_output[,"Std. Error"])
}

ci_robust = function(model, alpha=0.05, use_z_score=TRUE){
  if (use_z_score){
    z_score = qnorm(1 - alpha/2)
    se = se_robust(model)
    ci = cbind(coef(model) - z_score * se, coef(model) + z_score * se)
    colnames(ci) = c("2.5%", "97.5%")
  }
  else{ # t-score
    ci = coefci(model, level=1-alpha, vcov=vcovHC(model, type = "HC1"))
  }
  return(ci)
}

se_boot = function(samples_boot) apply(samples_boot, 2, sd)

ci_boot = function(samples_boot, alpha=0.05, method="percentile") {
  if (method!="percentile")
    stop("Only percentile method is implemented")
  
  probs = c(alpha/2, 1-alpha/2)
  ci_transposed = apply(samples_boot, 2, function(x){ 
    quantile(x, probs=probs)
  })
  ci = t(ci_transposed)
  
  return(ci)
}

get_beta_debiased = function(train, test, variable){
  # estimate error using train data
  train$error = train$Y_human - train$Y_llm
  model_error = lm(formula=paste("error", "~", variable), data=train)
  
  # compute Y_debiased for the test data, regress Y_debiased ~ Xvar on the test data
  test$error = predict(model_error, newdata=test) # predict error for test data
  test$Y_debiased = test$Y_llm + test$error
  model_debiased = lm(formula=paste("Y_debiased", "~", variable), data=test) 
  return(coef(model_debiased))
}

outer_loop_function = function(data, combination, save.rds=FALSE){
  set.seed(combination$id)
  major_topic = combination$major_topic
  variable = combination$variable
  model = combination$model 
  prompt = combination$prompt
  train_proportion = combination$train_proportion
  
  data = data %>% 
    filter(Model==model, 
           Prompt==prompt) %>%
    mutate(Y_human = as.integer(Major == major_topic),
           Y_llm = as.integer(MajorLLM == major_topic))
  
  # Using human-labeled major_topic topics on all 10K bills
  model_human = lm(formula=paste("Y_human", "~", variable), data=data)
  human.coef = coef(model_human)
  human.se = se_robust(model_human)
  human.lci = ci_robust(model_human, alpha=0.05, use_z_score=TRUE)[,1] # lower ci
  human.uci = ci_robust(model_human, alpha=0.05, use_z_score=TRUE)[,2] # upper ci
  
  names_betas = c("beta0", "beta1") # names(human.coef)
  n_betas = length(names_betas)
  betas = list(
    "major_topic"      = major_topic, 
    "variable"         = variable,
    "model"            = model,
    "prompt"           = prompt, 
    "train_proportion" = train_proportion,
    "sim_number" = 1:combination$N,
    "human" = list(
      "coef" = matrix(data=human.coef, nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE),
      "se"   = matrix(data=human.se,   nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE),
      "lci"  = matrix(data=human.lci,  nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE),
      "uci"  = matrix(data=human.uci,  nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE)),
    "llm" = list(
      "coef" = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "human_train" = list(
      "coef" = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "error" = list(
      "coef" = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "debiased" = list(
      "coef" = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=combination$N, ncol=n_betas, dimnames=list(NULL, names_betas)))
  )
  
  for (i in (1:combination$N)){ # outer loop
    # We randomly draw 5000 observations with replacement.
    data_sample = data[sample(x=nrow(data), size=combination$n_samples, replace=TRUE) ,]
    
    # On the 5000 observations, we calculate model_llm
    model_llm = lm(formula=paste("Y_llm", "~", variable), data=data_sample) 
    betas$llm$coef[i,] = coef(model_llm)
    betas$llm$se[i,] = se_robust(model_llm)
    betas$llm$lci[i,] = ci_robust(model_llm, alpha=0.05, use_z_score=TRUE)[,1] # lower ci
    betas$llm$uci[i,] = ci_robust(model_llm, alpha=0.05, use_z_score=TRUE)[,2] # upper ci
    
    # On the 5000 observations, we split the data into a train/test split. Since it's already a random sample, we don't do it using the sample function
    train_idx = 1:(nrow(data_sample) * train_proportion) # sample(x=nrow(data_sample), size=nrow(data_sample) * train_proportion, replace=FALSE)
    train = data_sample[train_idx, ]
    test = data_sample[-train_idx, ]
    
    # Using the train/test split, we calculate 
    # (i) model_human_train using only train. We calculate the se of model_human_train using heteroskedasticity robust standard errors.
    model_human_train = lm(formula=paste("Y_human", "~", variable), data=train)
    betas$human_train$coef[i,] = coef(model_human_train)
    betas$human_train$se[i,] = se_robust(model_human_train)
    betas$human_train$lci[i,] = ci_robust(model_human_train, alpha=0.05, use_z_score=TRUE)[,1] # lower ci
    betas$human_train$uci[i,] = ci_robust(model_human_train, alpha=0.05, use_z_score=TRUE)[,2] # upper ci
    
    # (ii) estimate error from train data
    train$error = train$Y_human - train$Y_llm
    model_error = lm(formula=paste("error", "~", variable), data=train)
    betas$error$coef[i,] = coef(model_error)
    betas$error$se[i,] = se_robust(model_error)
    betas$error$lci[i,] = ci_robust(model_error, alpha=0.05, use_z_score=TRUE)[,1] # lower ci
    betas$error$uci[i,] = ci_robust(model_error, alpha=0.05, use_z_score=TRUE)[,2] # upper ci
    
    # (iii) corrected error, and estimate debiased model
    betas$debiased$coef[i,] = get_beta_debiased(train=train, test=test, variable=variable)
    
    # We then begin the bootstrap (inner loop), this is beacuse beta_debiased is a function of a predicted Y_debiased and so we can't use se and ci from the lm model.
    debiased_coef_boot = as.data.frame(t(sapply(
      1:combination$B, 
      function(b){ # ignore b
        # We draw a bootstrap sample from each of the train and test data, keeping the train-test split fixed
        train_boot = train[sample(x=nrow(train), replace=TRUE), ]
        test_boot = test[sample(x=nrow(test), replace=TRUE), ]
        
        # Calculate the coef of the debiased model
        coef_boot = get_beta_debiased(train=train_boot, test=test_boot, variable=variable)
        return(coef_boot)
      }
    )))
    
    # We use bootstrap samples to calculate se and confidence intervals for corrected_beta.
    betas$debiased$se[i,] = se_boot(debiased_coef_boot)
    betas$debiased$lci[i,] = ci_boot(debiased_coef_boot, alpha=0.05, method="percentile")[,1] # lower ci
    betas$debiased$uci[i,] = ci_boot(debiased_coef_boot, alpha=0.05, method="percentile")[,2] # upper ci
  }
  
  betas_df = cbind(combination_id=combination$id, as.data.frame(betas))
  if (save.rds){
    saveRDS(betas_df, file=file.path(rds_dir, sprintf("combination%05d.rds", combination$id)))
    return(combination$id)
  } else 
    return(betas_df)
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

set.seed(123)
plan(multisession, workers = n_cores)
regressions = future_map(
  .options = furrr_options(seed=TRUE), # we also reset the seed inside .f using the combination index, e.g., set.seed(1)
  .x = 1:nrow(combinations),
  .f = function(x) {
    out = outer_loop_function(
      data=data,
      combination=combinations[x,]
    )
    return(out)}, 
  .progress=FALSE)
