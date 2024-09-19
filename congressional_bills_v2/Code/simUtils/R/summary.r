#' Summary of a Robust Object
#'
#' This method generates a summary of a robust object, including coefficients, standard errors, t-statistics, and confidence intervals.
#' @param object An object of class `robust`.
#' @param alpha The significance level for confidence intervals (default is 0.05).
#' @param z_score Logical indicating whether to use z-scores (default is TRUE).
#' @param ... Additional arguments passed to specific methods.
#' @return A data frame summarizing the model's coefficients, standard errors, and confidence intervals.
#' @export
summary.robust <- function(object, alpha=0.05, z_score=TRUE, ...){
  ci_value <- ci(object, alpha=alpha, z_score=z_score)
  return(data.frame(
    regression = object$regression_name, 
    coef_name = object$coef_name,
    coef = object$coef_vec,
    se = object$se, 
    t_stat = object$t_stat, 
    lci = ci_value[, 1], 
    uci = ci_value[, 2], 
    class = attr(object, "class"),
    row.names = NULL
  ))
}
#' Summary of a Bootstrap Object
#'
#' This method generates a summary of a bootstrap object, including coefficients, standard errors, t-statistics, and confidence intervals.
#' @param object A bootstrap object created by the `boot` function.
#' @param alpha The significance level for confidence intervals (default is 0.05).
#' @param z_score Logical indicating whether to use z-scores (default is TRUE).
#' @param ... Additional arguments passed to specific methods.
#' @return A data frame summarizing the bootstrapped coefficients, standard errors, and confidence intervals.
#' @export
summary.boot <- function(object, alpha=0.05, z_score=TRUE, ...){
  coef_value <- object$coef
  # Calculate standard errors from bootstrap samples
  se_value <- se(object)
  ci_value <- ci(object, alpha=alpha, z_score=z_score)
  t_value <- coef_value/se_value
  
  # Simplify coefficient names
  coef_name <- gsub("Yhuman|Yllm|Ytilde", "",  names(coef_value))
  coef_name <- gsub("V1", "V",  coef_name)
  
  return(data.frame(
    regression=object$regression, 
    coef_name=coef_name,  
    coef=coef_value, 
    se=se_value, 
    t_stat=t_value, 
    lci=ci_value[,1], 
    uci=ci_value[,2], 
    class=attr(object, "class"),
    row.names=NULL
  ))
}

#' Summary for a List of Objects
#'
#' This method generates a combined summary for a list of objects (e.g., robust or bootstrap objects).
#' @param ... A list of objects to summarize.
#' @param alpha The significance level for confidence intervals (default is 0.05).
#' @param z_score Logical indicating whether to use z-scores (default is TRUE).
#' @return A data frame summarizing the objects.
#' @export
summary.list <- function(..., alpha=0.05, z_score=TRUE){
  return(dplyr::bind_rows(lapply(..., summary, alpha=alpha, z_score=z_score)))
}