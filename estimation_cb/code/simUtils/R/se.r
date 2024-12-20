#' Generic Function for Standard Errors
#'
#' This is a generic function to extract standard errors from a variety of model objects. It dispatches methods based on the class of the input.
#' @param x An object for which standard errors are to be extracted.
#' @return A vector or matrix of standard errors, depending on the object type.
#' @export
se <- function(x) UseMethod("se")

#' Standard Errors for a Linear Model
#'
#' This method extracts standard errors from a fitted linear model (`lm` object).
#' @param x A linear model object (of class `lm`).
#' @return A vector of standard errors for the coefficients in the model.
#' @export
se.lm <- function(x) return(stats::summary.lm(x)$coef[, "Std. Error"])

#' Standard Errors for a summary object
#'
#' This method extracts standard errors from summary object of a linear model (`summary.lm` object).
#' @param x A summary object (of class `summary.lm`).
#' @return A vector of standard errors for the coefficients in the model.
#' @export
se.summary.lm <- function(x) return(x$coef[, "Std. Error"])

#' Standard Errors for a Multivariate Linear Model
#'
#' This method extracts standard errors for each response in a multivariate linear model (of class `mlm`).
#' @param x A multivariate linear model object (of class `mlm`).
#' @return A named vector of standard errors for each coefficient, separated by response variable.
#' @export
se.mlm <- function(x){
  model_names <- attr(summary(x), "names")
  out <- lapply(model_names, FUN = function(model_name){
    model_se <- se(summary(x)[[model_name]])
    dep_name <- sub("Response ", "", model_name)
    indep_name <- names(model_se)
    names(model_se) <- paste(dep_name, indep_name, sep = ":")
    return(model_se)
  })
  return(unlist(out))
}

#' Standard Errors for Robust Objects
#'
#' This method extracts standard errors from a robust object created by the `robust` function.
#' @param x An object of class `robust`.
#' @return A vector of robust standard errors.
#' @export
se.robust <- function(x) return(x$se) 

#' Standard Errors from Bootstrap Results
#'
#' This method calculates the standard errors from bootstrapped samples.
#' @param x A bootstrap object created by the `boot` function.
#' @return A vector of standard errors based on the bootstrap results.
#' @export
se.boot <- function(x) return(apply(x$boot, 2, stats::sd))
