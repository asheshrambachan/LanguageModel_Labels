#' Generic Function for Confidence Intervals
#'
#' This is a generic function to calculate confidence intervals. It dispatches methods based on the class of the input.
#' @param x An object for which confidence intervals are to be calculated.
#' @param alpha The significance level (default is 0.05).
#' @param z_score Logical indicating whether to use z-scores (default is TRUE). If FALSE, t-scores are used.
#' @return A matrix of confidence intervals, depending on the object type.
#' @export
ci <- function(x, alpha=0.05, z_score=TRUE) UseMethod("ci")

#' Confidence Intervals Using z-Score or t-Score
#'
#' This method calculates confidence intervals for a robust object, using either z-scores or t-scores.
#' @param x An object of class `robust`.
#' @param alpha The significance level (default is 0.05).
#' @param z_score Logical indicating whether to use z-scores (default is TRUE). If FALSE, t-scores are used.
#' @return A matrix of confidence intervals with lower and upper bounds.
#' @export
ci.default <- function(x, alpha=0.05, z_score=TRUE){
  probs <- c(alpha/2, 1-alpha/2)
  if (z_score) 
    score <- stats::qnorm(probs) 
  else # use t-score
    score <- stats::qt(probs, df=x$df)
  ci_value <- matrix(se(x), ncol=1) %*% matrix(score, ncol=2) + x$coef_vec
  colnames(ci_value) <- sprintf("%.1f%%", probs*100)
  return(ci_value)
}

#' Confidence Intervals for Bootstrap Results
#'
#' This method calculates confidence intervals from bootstrap samples using the percentile method.
#' @param x A bootstrap object created by the `boot` function.
#' @param alpha The significance level (default is 0.05).
#' @param z_score Logical indicating whether to use z-scores (default is TRUE).
#' @return A matrix of confidence intervals with lower and upper bounds.
#' @export
ci.boot <- function(x, alpha=0.05, z_score=TRUE){
  probs <- c(alpha/2, 1-alpha/2)
  ci_transposed <- apply(x$boot, 2, FUN=stats::quantile, probs=probs)
  ci_val <- t(ci_transposed)
  colnames(ci_val) <- sprintf("%.1f%%", probs*100)
  return(ci_val)
}