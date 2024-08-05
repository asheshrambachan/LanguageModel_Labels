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
  N = 10
  B = 15
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
    Y_human = factor(Major, levels=1:20),
    Y_llm = factor(MajorLLM, levels=1:20)) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Y_human, Y_llm) 
data = cbind(data, model.matrix(~ Y_human + 0, data=data), model.matrix(~ Y_llm + 0, data=data)) # one-hot # I assume that order here is preserved, and same as factor(, levels=1:20)
data[, c("Y_human", "Y_llm")] = NULL


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
combinations = combinations[1:10,] # TODO: remove this line

rds_paths_completed = list.files(rds_dir, pattern = "*.rds")
if (length(rds_paths_completed) != 0){
  combination_id_completed = as.numeric(gsub("combination|\\.rds", "", rds_paths_completed))
  combinations = combinations[-combination_id_completed, ] 
  cat(sprintf("Combination ID = %d has already been completed. Skipping.\n", combination_id_completed))
}

if (nrow(combinations)==0)
  stop("Current directory contains all rds files")

## Functions
se_robust = function(model){
  out = as.vector(matrix(NA, nrow=1, ncol=length(coef(model))))
  names(out) = names(coef(model))
  model_output = coeftest(model, vcov=vcovHC(model, type = "HC1"))
  out[rownames(model_output)] = model_output[,"Std. Error"]
  return(out)
}

ci_robust = function(model, alpha=0.05, use_z_score=TRUE){
  if (use_z_score){
    z_score = qnorm(1 - alpha/2)
    se = se_robust(model)
    out = cbind(coef(model) - z_score * se, coef(model) + z_score * se)
    colnames(out) = sprintf("%.1f %%", c(alpha/2, 1-alpha/2)*100) 
  }
  else{ # t-score
    out = matrix(NA, nrow=length(coef(model)), ncol=2)
    rownames(out) = names(coef(model))
    colnames(out) = sprintf("%.1f %%", c(alpha/2, 1-alpha/2)*100) 
    ci = coefci(model, level=1-alpha, vcov=vcovHC(model, type = "HC1"))
    out[rownames(ci),] = ci
  }
  return(out)
}

se_boot = function(samples_boot) apply(samples_boot, 2, sd, na.rm=TRUE) # TODO: check if NA remove

ci_boot = function(samples_boot, alpha=0.05, method="percentile") {
  if (method!="percentile")
    stop("Only percentile method is implemented")
  
  probs = c(alpha/2, 1-alpha/2)
  ci_transposed = apply(samples_boot, 2, function(x){ 
    quantile(x, probs=probs, na.rm=TRUE) # TODO: check if NA remove
  })
  ci = t(ci_transposed)
  
  return(ci)
}

get_beta_debiased = function(train, test){
  # train data
  
  # delta_{V, \hat{Y}}
  formula_indep = paste(sprintf("Y_llm%d", 1:20), collapse=" + ")
  formula = sprintf("V ~ %s + 0", formula_indep)
  model_V_Yllm = lm(formula, data=train) 
  
  # beta
  formula_indep = paste(sprintf("Y_human%d", 1:20), collapse=" + ")
  formula = sprintf("V ~ %s + 0", formula_indep)
  model_V_Yhuman = lm(formula, data=train) 
  
  # delta_{Y, \hat{Y}}
  formula_dep   = paste(sprintf("Y_human%d", 1:20), collapse=", ")
  formula_indep = paste(sprintf("Y_llm%d", 1:20), collapse=" + ")
  formula = sprintf("cbind(%s) ~ %s + 0", formula_dep, formula_indep)
  model_Yhuman_Yllm = lm(formula, data=train) # still using train data
  
  # coef
  # TODO: store model params? all: coef, se, ci, 
  delta_V_Yllm = coef(model_V_Yllm)
  beta = coef(model_V_Yhuman) # 20*1, Y_human * 1
  delta_Yhuman_Yllm = coef(model_Yhuman_Yllm) # 20*20, Y_llm * Y_human
  delta_nu_Yllm = delta_V_Yllm - delta_Yhuman_Yllm %*% beta # same as: as.matrix(beta, nrow=20)
  
  # Predict, test data
  
  # # Approach 1
  # # Y_tilde
  # Y_tilde_test = predict(model_Yhuman_Yllm, newdata=test)
  # colnames(Y_tilde_test) = sub("human","tilde", colnames(Y_tilde_test))
  # test = cbind(test, Y_tilde_test)
  # 
  # # V_tilde
  # major_id_missing = (1:20)[is.na(delta_nu_Yllm)]
  # major_id_avalible = (1:20)[!is.na(delta_nu_Yllm)]
  # delta_nu_Yllm = delta_nu_Yllm[major_id_avalible,]
  # Y_llm_test = as.matrix(test[sprintf("Y_llm%d", Y_llm_index_removedNA)])
  # test$V_tilde = test$V - Y_llm_test %*% delta_nu_Yllm

  # Approach 2
  test = cbind(test, predict(model_Yhuman_Yllm, newdata=test)) # Y_tilde = Y_human_pred using (Y_human ~ Y_llm) model
  test$V_tilde = test$V - (predict(model_V_Yllm, newdata=test) - predict(model_V_Yhuman, newdata=test)) # V_tilde = V - ((V ~ Y_llm) - (V ~ Y_human_pred))
  # alias(model_Yhuman_Yllm)
  # alias(model_V_Yllm)
  # alias(model_V_Yhuman)
  
  # Regress
  formula_indep = paste(sprintf("Y_human%d", 1:20), collapse=" + ")
  formula = sprintf("V_tilde ~ %s + 0", formula_indep)
  model_debiased = lm(formula, data=test)
  return(coef(model_debiased))
}

outer_loop_function = function(data, combination, N, B, n_samples){
  variable = combination$variable
  model = combination$model 
  prompt = combination$prompt
  train_proportion = combination$train_proportion
  
  data = data %>% 
    filter(Model==model, 
           Prompt==prompt) %>%
    mutate(V = .[[variable]])
  
  # Using human-labeled major_topic topics on all 10K bills
  formula_indep = paste(sprintf("Y_human%d", 1:20), collapse=" + ")
  formula = sprintf("V ~ %s + 0", formula_indep)
  model_human = lm(formula, data=data)
  human.coef = coef(model_human)
  human.se = se_robust(model_human)
  human.lci = ci_robust(model_human, alpha=0.05, use_z_score=TRUE)[,1] # lower ci
  human.uci = ci_robust(model_human, alpha=0.05, use_z_score=TRUE)[,2] # upper ci
  
  names_betas = names(human.coef)
  n_betas = length(names_betas)
  betas = list(
    "variable"         = variable, 
    "model"            = model, 
    "prompt"           = prompt, 
    "train_proportion" = train_proportion, 
    "sim_number" = 1:N,
    "human" = list(
      "coef" = matrix(data=human.coef, nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE),
      "se"   = matrix(data=human.se,   nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE),
      "lci"  = matrix(data=human.lci,  nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE),
      "uci"  = matrix(data=human.uci,  nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas), byrow = TRUE)),
    "llm" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "human_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "V_Yllm_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "V_Yhuman_train" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    # "Yhuman_Yllm_train" = list(
    #   "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
    #   "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
    #   "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
    #   "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
    "debiased" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)))
  )
  
  for (i in (1:N)){ # outer loop
    # We randomly draw 5000 observations with replacement.
    data_sample = data[sample(x=nrow(data), size=n_samples, replace=TRUE) ,]
    
    # On the 5000 observations, we calculate model_llm
    formula_indep = paste(sprintf("Y_llm%d", 1:20), collapse=" + ")
    formula = sprintf("V ~ %s + 0", formula_indep)
    model_llm = lm(formula, data=data_sample) # TODO: confirm no intercept
    betas$llm$coef[i,] = coef(model_llm)
    betas$llm$se[i,] = se_robust(model_llm)
    betas$llm$lci[i,] = ci_robust(model_llm, alpha=0.05, use_z_score=TRUE)[,1]
    betas$llm$uci[i,] = ci_robust(model_llm, alpha=0.05, use_z_score=TRUE)[,2]
    
    # On the 5000 observations, we split the data into a train/test split. Since it's already a random sample, we don't do it using the sample function
    train_idx = 1:(nrow(data_sample) * train_proportion)
    train = data_sample[train_idx, ]
    test = data_sample[-train_idx, ]
    test[, sprintf("Y_human%d",1:20)] = NULL
    
    # Using the train/test split, we calculate 
    # (i) model_human_train using only train. We calculate the se of model_human_train using heteroskedasticity robust standard errors.
    formula_indep = paste(sprintf("Y_human%d", 1:20), collapse=" + ")
    formula = sprintf("V ~ %s + 0", formula_indep)
    model_human_train = lm(formula, data=train)
    betas$human_train$coef[i,] = coef(model_human_train)
    betas$human_train$se[i,] = se_robust(model_human_train)
    betas$human_train$lci[i,] = ci_robust(model_human_train, alpha=0.05, use_z_score=TRUE)[,1] 
    betas$human_train$uci[i,] = ci_robust(model_human_train, alpha=0.05, use_z_score=TRUE)[,2] 
    
    # delta_{V, \hat{Y}}
    formula_indep = paste(sprintf("Y_llm%d", 1:20), collapse=" + ")
    formula = sprintf("V ~ %s + 0", formula_indep)
    model_V_Yllm = lm(formula, data=train) 
    betas$V_Yllm_train$coef[i,] = coef(model_V_Yllm)
    betas$V_Yllm_train$se[i,] = se_robust(model_V_Yllm)
    betas$V_Yllm_train$lci[i,] = ci_robust(model_V_Yllm, alpha=0.05, use_z_score=TRUE)[,1] 
    betas$V_Yllm_train$uci[i,] = ci_robust(model_V_Yllm, alpha=0.05, use_z_score=TRUE)[,2] 
    
    # beta
    formula_indep = paste(sprintf("Y_human%d", 1:20), collapse=" + ")
    formula = sprintf("V ~ %s + 0", formula_indep)
    model_V_Yhuman = lm(formula, data=train) 
    betas$V_Yhuman_train$coef[i,] = coef(model_V_Yhuman)
    betas$V_Yhuman_train$se[i,] = se_robust(model_V_Yhuman)
    betas$V_Yhuman_train$lci[i,] = ci_robust(model_V_Yhuman, alpha=0.05, use_z_score=TRUE)[,1] 
    betas$V_Yhuman_train$uci[i,] = ci_robust(model_V_Yhuman, alpha=0.05, use_z_score=TRUE)[,2] 
    
    # delta_{Y, \hat{Y}}
    formula_dep   = paste(sprintf("Y_human%d", 1:20), collapse=", ")
    formula_indep = paste(sprintf("Y_llm%d", 1:20), collapse=" + ")
    formula = sprintf("cbind(%s) ~ %s + 0", formula_dep, formula_indep)
    model_Yhuman_Yllm = lm(formula, data=train) # still using train data
    # TODO: How to store this model params
    # betas$Yhuman_Yllm_train$coef[i,] = coef(model_Yhuman_Yllm) 
    # betas$Yhuman_Yllm_train$se[i,] = se_robust(model_Yhuman_Yllm)
    # betas$Yhuman_Yllm_train$lci[i,] = ci_robust(model_Yhuman_Yllm, alpha=0.05, use_z_score=TRUE)[,1] 
    # betas$Yhuman_Yllm_train$uci[i,] = ci_robust(model_Yhuman_Yllm, alpha=0.05, use_z_score=TRUE)[,2] 
    
    betas$debiased$coef[i,] = get_beta_debiased(train=train, test=test)
    
    # We then begin the bootstrap (inner loop), this is because beta_debiased is a function of a predicted Y_debiased and so we can't use se and ci from the lm model.
    debiased_coef_boot = as.data.frame(t(sapply(
      1:B, 
      function(b){ # ignore b
        # We draw a bootstrap sample from each of the train and test data, keeping the train-test split fixed
        train_boot = train[sample(x=nrow(train), replace=TRUE), ]
        test_boot = test[sample(x=nrow(test), replace=TRUE), ]
        
        # Calculate the coef of the debiased model
        coef_boot = get_beta_debiased(train=train_boot, test=test_boot)
        return(coef_boot)
      }
    )))
    
    # We use bootstrap samples to calculate se and confidence intervals for corrected_beta.
    betas$debiased$se[i,] = se_boot(debiased_coef_boot)
    betas$debiased$lci[i,] = ci_boot(debiased_coef_boot, alpha=0.05, method="percentile")[,1] # lower ci
    betas$debiased$uci[i,] = ci_boot(debiased_coef_boot, alpha=0.05, method="percentile")[,2] # upper ci
  }
  
  return(as.data.frame(betas))
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

out_list = future_map(
  .options = furrr_options(seed=TRUE), # we also reset the seed inside .f using the combination index, e.g., set.seed(1)
  .x = 1:nrow(combinations),
  .f = function(x) {
    combination_id = combinations[x,]$id
    print(combination_id)
    set.seed(combination_id)
    betas_df = outer_loop_function(
      data=data,
      combination=combinations[combination_id,],
      N=N,
      B=B,
      n_samples=n_samples
    )
    betas_df = cbind(combination_id=combination_id, betas_df)
    saveRDS(betas_df, file=file.path(rds_dir, sprintf("combination%05d.rds", combination_id)))
    return(betas_df) #list("seed"=combination_id, "combination_id"=combination_id))
  }, 
  .progress=FALSE)
