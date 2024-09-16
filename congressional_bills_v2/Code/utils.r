# ------------------------------------------------------------------
# Script Name: utils.R
# Created: Jul 31, 2024
# 
# This file contains utility functions used when running the simulations.
#
# Note: This code is based on  https://github.com/asheshrambachan/LanguageModel_Labels/blob/main/egami_et_al/code/LLM_errors.R
# -------------------------------------------------------------------

# (1) Generic Functions
# (1.1) Recode using provided list of topics, converting the non-included topics to "Other"
recode_topics <- function(x, topics){
  x_recoded <- addNA(factor(x, levels=topics))  # Recode factor levels, including NA
  n <- nlevels(x_recoded)
  if (is.na(levels(x_recoded)[n]))
    levels(x_recoded)[n] <- "Other" # Label NA levels as "Other"
  return(x_recoded)
}

# Extract coefficients from a robust object
coef.robust <- function(robust) return(robust$coef)

# Generic function for standard errors
se <- function(x) UseMethod("se")

# Standard errors for a default model (e.g., lm)
se.lm <- function(model) return(summary.lm(model)$coef[, "Std. Error"])

# Standard errors for multivariate linear models (mlm)
se.summary.lm <- function(summary.lm) return(summary.lm$coef[, "Std. Error"])
se.mlm <- function(mlm){
  model_names <- attr(summary(mlm), "names")
  out <- lapply(model_names, FUN = function(model_name){
    model_se <- se(summary(mlm)[[model_name]])
    dep_name <- sub("Response ", "", model_name)
    indep_name <- names(model_se)
    names(model_se) <- paste(dep_name, indep_name, sep = ":")
    return(model_se)
  })
  return(unlist(out))
}

# Standard errors for robust objects
se.robust <- function(robust) return(robust$se) 

# Standard errors for bootstrapped results
se.boot <- function(boot) return(apply(boot$boot, 2, sd))

# Generic function for confidence intervals
ci <- function(x, ...) UseMethod("ci")

# Confidence intervals using z-score or t-score
ci.default <- function(robust, alpha=0.05, z_score=TRUE){
  probs <- c(alpha/2, 1-alpha/2)
  if (z_score) 
    score <- qnorm(probs) 
  else # use t-score
    score <- qt(probs, df=robust$df)
  ci_value <- matrix(se(robust), ncol=1) %*% matrix(score, ncol=2) + robust$coef_vec
  colnames(ci_value) <- sprintf("%.1f%%", probs*100)
  return(ci_value)
}

# Confidence intervals from bootstrap samples using the percentile method
ci.boot <- function(boot, alpha=0.05, z_score=TRUE){
  probs <- c(alpha/2, 1-alpha/2)
  ci_transposed <- apply(boot$boot, 2, FUN=quantile, probs=probs)
  ci_val <- t(ci_transposed)
  colnames(ci_val) <- sprintf("%.1f%%", probs*100)
  return(ci_val)
}

# Create a robust data object
robust <- function(x, ...) UseMethod("robust")
robust.default <- function(model, regression.name, suppressWarnings=F){ 
  if(any(se(model)==0)){
    msg <- sprintf("%s essentially perfect fit: summary may be unreliable", regression.name)
    if(!suppressWarnings) warning(simpleWarning(msg))
  }
  
  # Calculate robust standard errors
  model_robust <- withCallingHandlers(
    expr = coeftest(model, vcov=vcovHC(model, type="HC1")),
    warning = function(w){
      msg <- sprintf("%s %s", regression.name, conditionMessage(w))
      if(!suppressWarnings) warning(simpleWarning(msg))
      invokeRestart("muffleWarning")
    }
  )
  
  # Simplify coefficient names
  rownames(model_robust) <- gsub("Yhuman|Yllm|Ytilde", "", rownames(model_robust))
  rownames(model_robust) <- gsub("V1", "V", rownames(model_robust))
  
  robust <- structure(
    list(
      regression.name = regression.name,
      df.residual = attr(model_robust, "df"),
      coef = model$coef,
      coef_name = rownames(model_robust),
      coef_vec = model_robust[, "Estimate"], #model$coef,
      se = model_robust[, "Std. Error"],
      t_stat = model_robust[, "t value"]
    ),
    class = "robust"
  )
  return(robust)
}

# Create a bootstarp data object
boot <- function(fun, B, type.boot=c("bayesian", "nonparametric"), fun_out_boot, train, test){
  type.boot <- match.arg(type.boot)
  out <- list()
  
  fun_out <- fun(train=train, test=test)
  if (any(!(fun_out_boot %in% names(fun_out))))
    stop("Listed coefficents to bootstrap are not among the output of the function")
  
  # setup output template
  for (var in fun_out_boot){
    var_coef <- fun_out[[var]]
    out <- append(out, list(
      structure(
        list(
          coef = var_coef, 
          boot = matrix(NA, nrow=B, ncol=length(var_coef), dimnames=list(NULL, names(var_coef))), 
          coef_name = names(var_coef), 
          regression.name = sub("coef_", "", var)),
        class="boot"
      )
    ))
  }
  
  other_out <- names(fun_out)[!(names(fun_out) %in% fun_out_boot)]
  for (var in other_out){
    out <- append(out, list(fun_out[[var]]))
  }
  names(out) <- c(fun_out_boot, other_out)
  
  for (b in 1:B){
    train_boot <- train
    test_boot <- test
    
    # Resample or change sample weights if a bootstrap method is specified
    if (type.boot=="nonparametric"){
      train_boot <- train_boot[sample(x=nrow(train_boot), replace=TRUE), ]
      test_boot <- test_boot[sample(x=nrow(test_boot), replace=TRUE), ]
    } else if (type.boot=="bayesian") {
      w_train <- rgamma(nrow(train_boot), shape=1, scale=1) 
      w_test <- rgamma(nrow(test_boot), shape=1, scale=1)
      train_boot$w <- w_train/sum(w_train)
      test_boot$w <- w_test/sum(w_test)
    } 
    
    fun_out <- fun(train=train_boot, test=test_boot)
    for (var in fun_out_boot){
      out[[var]]$boot[b,] = fun_out[[var]]
    }
  }
  
  return(out)
}



# Generate a summary of a robust object
summary.robust <- function(robust, alpha=0.05, z_score=TRUE){
  ci_value <- ci(robust, alpha=alpha, z_score=z_score)
  return(data.frame(
    regression = robust$regression.name, 
    coef_name = robust$coef_name,
    coef = robust$coef_vec,
    se = robust$se, 
    t_stat = robust$t_stat, 
    lci = ci_value[, 1], 
    uci = ci_value[, 2], 
    class = attr(robust, "class"),
    row.names = NULL
  ))
}

# Generate a summary of a bootstrap object
summary.boot <- function(boot, alpha=0.05, z_score=TRUE){
  coef_value <- boot$coef
  # Calculate standard errors from bootstrap samples
  se_value <- se(boot)
  ci_value <- ci(boot, alpha=alpha, z_score=z_score)
  t_value <- coef_value/se_value
  
  # Simplify coefficient names
  coef_name <- gsub("Yhuman|Yllm|Ytilde", "",  names(coef_value))
  coef_name <- gsub("V1", "V",  coef_name)
  
  return(data.frame(
    regression=boot$regression, 
    coef_name=coef_name,  
    coef=coef_value, 
    se=se_value, 
    t_stat=t_value, 
    lci=ci_value[,1], 
    uci=ci_value[,2], 
    class=attr(boot, "class"),
    row.names=NULL
  ))
}

# generate summary for mixture of objects
summary.list <- function(..., alpha=0.05, z_score=TRUE){
  return(bind_rows(lapply(..., summary, alpha=alpha, z_score=z_score)))
}
