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
  N = 2
  B = 10
  n_cores = 10
}

n_samples = 5000
common_major_topics = c(3, 14, 15, 19, 20)
train_proportion = c(0.1, 0.25, 0.5)

simulation_dir = file.path(repo_dir, "04_simulation")
setwd(simulation_dir)

data = read.csv(file.path(repo_dir, "02_llm/bills_prompts_responses_10000.csv")) %>% 
  mutate(
    Senate = as.integer(Chamber == "Senate"),
    Democrat = as.integer(Party == "Democrat"),
    Prompt = PromptingStrategyID) %>% 
  select(Model, Prompt, BillID, Senate, Democrat, DW1, Major, MajorLLM) 

rds_dir = file.path(simulation_dir, sprintf("rds_N%d_B%d", N, B)) 
dir.create(rds_dir, showWarnings=FALSE)

# bills = data %>%
#   group_by(BillID) %>%
#   summarise(Major = first(Major))
# common_major_topics_table = sort(summary(as.factor(bills$Major)), decreasing=TRUE)[1:5]
# common_major_topics = sort(as.integer(names(common_major_topics_table)))

combinations = expand.grid(
  train_proportion = train_proportion, # 10%train 90%test, ...
  prompt = unique(data$Prompt),
  model = unique(data$Model),
  variable = c("Senate", "Democrat", "DW1"),
  major_topic = common_major_topics, 
  stringsAsFactors = FALSE
)
combinations$id = 1:nrow(combinations)
rds_paths_completed = list.files(rds_dir, pattern = "*.rds")
if (length(rds_paths_completed) != 0){
  combination_id_completed = as.numeric(gsub("combination|\\.rds", "", rds_paths_completed))
  combinations = combinations[-combination_id_completed, ] 
  cat(sprintf("Combination ID = %d has already been completed. Skipping.\n", combination_id_completed))
}

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

outer_loop_function = function(data, combination, N, B, n_samples){
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
    "major_topic"      = major_topic, # matrix(data=major_topic, nrow=N, ncol=1),
    "variable"         = variable, # matrix(data=variable, nrow=N, ncol=1),
    "model"            = model, # matrix(data=model, nrow=N, ncol=1),
    "prompt"           = prompt, # matrix(data=prompt, nrow=N, ncol=1),
    "train_proportion" = train_proportion, # matrix(data=train_proportion, nrow=N, ncol=1),
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
    "error" = list(
      "coef" = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "se"   = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "lci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas)),
      "uci"  = matrix(nrow=N, ncol=n_betas, dimnames=list(NULL, names_betas))),
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
      1:B, 
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
# with_progress({
#   p = progressor(along = 1:nrow(combinations))
future_map(
  .options = furrr_options(seed=TRUE), # we also reset the seed inside .f using the combination index, e.g., set.seed(1)
  .x = combinations$id,
  .f = function(x) {
    set.seed(x)
    betas_df = outer_loop_function(
      data=data,
      combination=combinations[x,],
      N=N,
      B=B,
      n_samples=n_samples
    )
    betas_df = cbind(combination_id=x, betas_df)
    saveRDS(betas_df, file=file.path(rds_dir, sprintf("combination%05d.rds", x)))
    # p(sprintf("completed and saved combination%05d.rds", x))
    }, 
  .progress=TRUE)
# }, enable = TRUE) # , delay_stdout=TRUE, delay_conditions="condition")
