
## Functions

# Recode using provided list of topics, converting the non-included topics to "Other"
recode_topics <- function(x, topics){
  x_recoded <- addNA(factor(x, levels=topics))  # Recode factor levels, including NA
  n <- nlevels(x_recoded)
  if (is.na(levels(x_recoded)[n]))
    levels(x_recoded)[n] = "Other" # Label NA levels as "Other"
  return(x_recoded)
}

# Generate a summary of the regression model using robust standard errors
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

# Generate a summary of the bootstrap results, including standard errors and confidence intervals
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
