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

repo_dir = "~/Documents/LanguageModel_Labels/congressional_bills"

args = commandArgs(trailingOnly = TRUE)
if (length(args)>0){
  N = as.numeric(args[1])
  B = as.numeric(args[2])
  n_cores = as.numeric(args[3])
} else {
  N = 1
  B = 10
  n_cores = 10
}

n_samples = 5000 # 5000 
train_proportion = c(0.1, 0.25, 0.5)

simulation_dir = file.path(repo_dir, "04_simulation")
setwd(simulation_dir)

data = read.csv(file.path(repo_dir, "02_llm/bills_prompts_responses_10000.csv")) %>% 
  mutate(
    Senate = as.integer(Chamber == "Senate"),
    Democrat = as.integer(Party == "Democrat"),
    Prompt = PromptingStrategyID,
    Y_human = Major,
    Y_llm = MajorLLM) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Y_human, Y_llm)

bills = data %>%
  group_by(BillID) %>%
  summarise(Y_human = first(Y_human), Y_llm = first(Y_llm))
Y_human_common_table = sort(summary(as.factor(bills$Y_human)), decreasing=TRUE)
Y_llm_common_table = sort(summary(as.factor(bills$Y_llm)), decreasing=TRUE)
Y_human_common = as.integer(names(Y_human_common_table))[1:5]
Y_llm_common = as.integer(names(Y_llm_common_table))[1:5]

data$Y_human_common = addNA(factor(data$Y_human, levels=Y_human_common, labels=1:5))
data$Y_llm_common = addNA(factor(data$Y_llm, levels=Y_llm_common, labels=1:5))
levels(data$Y_human_common) = 1:6
levels(data$Y_llm_common) = 1:6



rds_dir = file.path(simulation_dir, sprintf("rds_rhs_N%d_B%d", N, B)) 
dir.create(rds_dir, showWarnings=FALSE)

combinations = expand.grid(
  train_proportion = train_proportion, # 10%train 90%test, ...  
  prompt = unique(data$Prompt),
  model = unique(data$Model),
  variable = c("Senate", "Democrat", "DW1"), 
  stringsAsFactors = FALSE
)
combinations = cbind(id = 1:nrow(combinations), combinations)

# rds_paths_completed = list.files(rds_dir, pattern = "*.rds")
# if (length(rds_paths_completed) != 0){
#   combination_id_completed = as.numeric(gsub("combination|\\.rds", "", rds_paths_completed))
#   combinations = combinations[-combination_id_completed, ] 
#   cat(sprintf("Combination ID = %d has already been completed. Skipping.\n", combination_id_completed))
# }
# if (nrow(combinations)==0)
#   stop("Current directory contains all rds files")


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
# 
# ## Functions
# se_robust = function(model){
#   out = as.vector(matrix(NA, nrow=1, ncol=length(coef(model))))
#   names(out) = names(coef(model))
#   model_output = coeftest(model, vcov=vcovHC(model, type = "HC1"))
#   out[rownames(model_output)] = model_output[,"Std. Error"]
#   return(out)
# }
# 
# ci_robust = function(model, alpha=0.05, use_z_score=TRUE){
#   if (use_z_score){
#     z_score = qnorm(1 - alpha/2)
#     se = se_robust(model)
#     out = cbind(coef(model) - z_score * se, coef(model) + z_score * se)
#     colnames(out) = sprintf("%.1f %%", c(alpha/2, 1-alpha/2)*100) 
#   }
#   else{ # t-score
#     out = matrix(NA, nrow=length(coef(model)), ncol=2)
#     rownames(out) = names(coef(model))
#     colnames(out) = sprintf("%.1f %%", c(alpha/2, 1-alpha/2)*100) 
#     ci = coefci(model, level=1-alpha, vcov=vcovHC(model, type = "HC1"))
#     out[rownames(ci),] = ci
#   }
#   return(out)
# }
# 
# se_boot = function(samples_boot) apply(samples_boot, 2, sd, na.rm=TRUE) # TODO: check if NA remove
# 
# ci_boot = function(samples_boot, alpha=0.05, method="percentile") {
#   if (method!="percentile")
#     stop("Only percentile method is implemented")
#   
#   probs = c(alpha/2, 1-alpha/2)
#   ci_transposed = apply(samples_boot, 2, function(x){ 
#     quantile(x, probs=probs, na.rm=TRUE) # TODO: check if NA remove
#   })
#   ci = t(ci_transposed)
#   
#   return(ci)
# }

get_Vtilde_Ytilde_coef = function(train, test, boot=NULL){
  train$w = 1
  test$w = 1
  
  if (!is.null(boot)){
    if (boot=="nonparametric"){
      train = train[sample(x=nrow(train), replace=TRUE), ]
      test = test[sample(x=nrow(test), replace=TRUE), ]
    } else if (boot=="bayesian") {
      w_train = rgamma(nrow(train), shape=1, scale=1) # rexp(n=nrow(train), rate=1)
      train$w = w_train/sum(w_train) # train_weight_sum = sum(train$w)
      
      # TODO: confirm that the only regression where we use the test weights is V_tilde ~ Y_tilde + 0, data=test
      w_test = rgamma(nrow(test), shape=1, scale=1)
      test$w = w_test/sum(w_test)
    } else 
      stop('Incorrect boot method specified. boot = c("nonparametric", "bayesian")')
  }
  
  # train data
  # beta in debiased model coef (this is also model_V_Yhuman_train)
  model_V_Yhuman_train = lm(V ~ Y_human_common + 0, weights=w, data=train)
  beta = coef(model_V_Yhuman_train) # 20*1, Y_human * 1 # solve(t(model.matrix(~ Y_human_common + 0, data=train)) %*% diag(train$w) %*% model.matrix(~ Y_human_common + 0, data=train)) %*% t(model.matrix(~ Y_human_common + 0, data=train)) %*% diag(train$w) %*% train$V
  
  # delta_{V, \hat{Y}}
  model_V_Yllm_train = lm(V ~ Y_llm_common + 0, weights=w, data=train) 
  delta_V_Yllm = coef(model_V_Yllm_train)
  
  # delta_{Y, \hat{Y}}
  Y_human_common_train = model.matrix(~ Y_human_common + 0, data=train)
  formula = sprintf("cbind(%s) ~ Y_llm_common + 0", paste(colnames(Y_human_common_train), collapse=", "))
  model_Yhuman_Yllm_train = lm(formula, weights = w, data=cbind(train, Y_human_common_train)) 
  delta_Yhuman_Yllm = coef(model_Yhuman_Yllm_train) # 20*20, Y_llm * Y_human
  
  # delta_{nu, \hat{Y}} = delta_{V, \hat{Y}} - delta_{Y, \hat{Y}} beta
  delta_nu_Yllm = as.vector(delta_V_Yllm - delta_Yhuman_Yllm %*% beta) 
  
  # Predict, test data
  # Y_tilde (predicted Y_human)
  Y_llm_common_test = model.matrix(~ Y_llm_common + 0, data=test)
  Y_tilde_common_test = Y_llm_common_test %*% delta_Yhuman_Yllm # same as # predict(model_Yhuman_Yllm_train, newdata=test)
  colnames(Y_tilde_common_test) = sub("human","tilde", colnames(Y_tilde_common_test))
  
  # V_tilde
  test$V_tilde = test$V - Y_llm_common_test %*% delta_nu_Yllm # V_tilde = V - ((V ~ Y_llm) - (V ~ Y_human_pred)) = test$V - (Y_llm_common_test %*% delta_V_Yllm - Y_tilde_common %*% beta) 
  
  # Regress and get coef
  formula = sprintf("V_tilde ~ %s + 0", paste(colnames(Y_tilde_common_test), collapse=" + "))
  model_Vtilde_Ytilde_test = lm(formula, weights = w, data=cbind(test, Y_tilde_common_test)) # TODO: here is the only place where we use the test weight
  coef_boot = coef(model_Vtilde_Ytilde_test) 
  
  return(coef_boot)
}

outer_loop_function = function(data, combination, N, B, n_samples){
  set.seed(combination$id)
  variable = combination$variable
  model = combination$model 
  prompt = combination$prompt
  train_proportion = combination$train_proportion
  
  data = data %>% 
    filter(Model==model, 
           Prompt==prompt) %>%
    mutate(V = .[[variable]])
  
  # Using human-labeled major_topic topics on all 10K bills
  model_V_Yhuman = lm(V ~ Y_human_common + 0, data=data)
  human.coef = coef(model_V_Yhuman)
  human.se = se_robust(model_V_Yhuman)
  human.lci = ci_robust(model_V_Yhuman, alpha=0.05, use_z_score=TRUE)[,1] # lower ci
  human.uci = ci_robust(model_V_Yhuman, alpha=0.05, use_z_score=TRUE)[,2] # upper ci
  
  names_betas = names(human.coef)
  n_betas = length(names_betas)
  betas = list(
    "variable"         = variable, 
    "model"            = model, 
    "prompt"           = prompt, 
    "train_proportion" = train_proportion, 
    "sim_number" = 1:N,
    "V_Yhuman" = list(
      "coef" = matrix(data=human.coef, nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE),
      "se"   = matrix(data=human.se,   nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE),
      "lci"  = matrix(data=human.lci,  nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE),
      "uci"  = matrix(data=human.uci,  nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE)),
    "V_Yllm" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "V_Yhuman_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "V_Yllm_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "Yhuman1_Yllm_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "Yhuman2_Yllm_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "Yhuman3_Yllm_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "Yhuman4_Yllm_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "Yhuman5_Yllm_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "Yhuman6_Yllm_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "Vtilde_Ytilde" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)))
  )
  
  for (i in (1:N)){ # outer loop
    # We randomly draw 5000 observations with replacement.
    data_sample = data[sample(x=nrow(data), size=n_samples, replace=TRUE) ,]
    
    # On the 5000 observations, we calculate model_V_Yllm
    model_V_Yllm = lm(V ~ Y_llm_common + 0, data=data_sample) # TODO: confirm no intercept
    betas$V_Yllm$coef[i,] = coef(model_V_Yllm)
    betas$V_Yllm$se[i,] = se_robust(model_V_Yllm)
    betas$V_Yllm$lci[i,] = ci_robust(model_V_Yllm, alpha=0.05, use_z_score=TRUE)[,1]
    betas$V_Yllm$uci[i,] = ci_robust(model_V_Yllm, alpha=0.05, use_z_score=TRUE)[,2]
    
    # On the 5000 observations, we split the data into a train/test split. Since it's already a random sample, we don't do it using the sample function
    train_idx = 1:(n_samples * train_proportion)
    train = data_sample[train_idx, ]
    test = data_sample[-train_idx, ]
    test$Y_human_common = NULL
    
    # Using the train/test split, we calculate 
    # (i) model_V_Yhuman_train using only train. We calculate the se of model_V_Yhuman_train using heteroskedasticity robust standard errors.
    # (ii) Debiased model coef
    
    # beta in debiased model coef (this is also model_V_Yhuman_train)
    model_V_Yhuman_train = lm(V ~ Y_human_common + 0, data=train)
    beta = coef(V_Yhuman_train)
    
    betas$V_Yhuman_train$coef[i,] = coef(model_V_Yhuman_train)
    betas$V_Yhuman_train$se[i,] = se_robust(model_V_Yhuman_train)
    betas$V_Yhuman_train$lci[i,] = ci_robust(model_V_Yhuman_train, alpha=0.05, use_z_score=TRUE)[,1] 
    betas$V_Yhuman_train$uci[i,] = ci_robust(model_V_Yhuman_train, alpha=0.05, use_z_score=TRUE)[,2] 
    
    # delta_{V, \hat{Y}}
    model_V_Yllm_train = lm(V ~ Y_llm_common + 0, data=train) 
    delta_V_Yllm = coef(model_V_Yllm_train)
    
    betas$V_Yllm_train$coef[i,] = coef(model_V_Yllm_train)
    betas$V_Yllm_train$se[i,] = se_robust(model_V_Yllm_train)
    betas$V_Yllm_train$lci[i,] = ci_robust(model_V_Yllm_train, alpha=0.05, use_z_score=TRUE)[,1] 
    betas$V_Yllm_train$uci[i,] = ci_robust(model_V_Yllm_train, alpha=0.05, use_z_score=TRUE)[,2] 
    
    # delta_{Y, \hat{Y}}
    Y_human_common_onehot_train = model.matrix(~ Y_human_common + 0, data=train)
    formula_dep = paste(colnames(Y_human_common_onehot_train), collapse=", ")
    formula = sprintf("cbind(%s) ~ Y_llm_common + 0", formula_dep)
    model_Yhuman_Yllm_train = lm(formula, data=cbind(train, Y_human_common_onehot_train))
    delta_Yhuman_Yllm = coef(model_Yhuman_Yllm_train)
    
    # to store the model parameter, we redo the regression, but one dependent variable at a time
    for (dep_id in 1:ncol(Y_human_common_onehot_train)){
      dep_name = colnames(Y_human_common_onehot_train)[dep_id]
      model_Yhuman_Yllm_train_dep = lm(sprintf("%s ~ Y_llm_common + 0", dep_name), data=cbind(train, Y_human_common_onehot_train)) 
      dep_out_var_name = sprintf("Yhuman%d_Yllm_train", dep_id)
      betas[[dep_out_var_name]]$ coef[i,] = coef(model_Yhuman_Yllm_train_dep)
      betas[[dep_out_var_name]]$ se[i,] = se_robust(model_Yhuman_Yllm_train_dep)
      betas[[dep_out_var_name]]$ lci[i,] = ci_robust(model_Yhuman_Yllm_train_dep, alpha=0.05, use_z_score=TRUE)[,1]
      betas[[dep_out_var_name]]$ uci[i,] = ci_robust(model_Yhuman_Yllm_train_dep, alpha=0.05, use_z_score=TRUE)[,2]
    }
    
    
    betas$Vtilde_Ytilde$coef[i,] = get_Vtilde_Ytilde_coef(train=train, test=test)
    
    # We then begin the bootstrap (inner loop), this is because beta_debiased is a function of a predicted Y_debiased and so we can't use se and ci from the lm model.
    
    # debiased_coef_boot = as.data.frame(t(sapply(
    #   1:B, 
    #   function(b){ # ignore b
    #     coef_boot = get_Vtilde_Ytilde_coef(train=train_boot, test=test_boot)
    #     return(coef_boot)
    #   }
    # )))
    
    Vtilde_Ytilde_coef_boot = matrix(nrow=B, ncol=n_betas)
    for (b in 1:B){
      coef_boot = get_Vtilde_Ytilde_coef(train=train, test=test)
      if (length(coef_boot) != n_betas)
        print(combination$id, coef_boot)
      Vtilde_Ytilde_coef_boot[b,] = coef_boot
    }
    
    # We use bootstrap samples to calculate se and confidence intervals for corrected_beta.
    betas$Vtilde_Ytilde$se[i,] = se_boot(Vtilde_Ytilde_coef_boot)
    betas$Vtilde_Ytilde$lci[i,] = ci_boot(Vtilde_Ytilde_coef_boot, alpha=0.05, method="percentile")[,1] # lower ci
    betas$Vtilde_Ytilde$uci[i,] = ci_boot(Vtilde_Ytilde_coef_boot, alpha=0.05, method="percentile")[,2] # upper ci
  }
  
  betas_df = cbind(combination_id=combination$id, as.data.frame(betas))
  saveRDS(betas_df, file=file.path(rds_dir, sprintf("combination%05d.rds", combination$id)))
  return(betas_df)
}

## Models
if (n_cores > parallelly::availableCores())
  n_cores = parallelly::availableCores()
cat(sprintf("N = %d, B = %d, n_cores = %d\n", N, B, n_cores))
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

for (x in 1:nrow(combinations)){
  out = outer_loop_function(
    data=data,
    combination=combinations[x,],
    N=N,
    B=B,
    n_samples=n_samples
  )
}

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
    )
    # return(betas_df) #list("seed"=combination_id, "combination_id"=combination_id))
  }, 
  .progress=FALSE)
