#' Extract Coefficients from a Robust Object
#'
#' This function extracts the coefficient estimates from a robust object created using the `robust` function.
#' @param object An object of class `robust` containing the model's robust results.
#' @param ... Additional arguments passed to specific methods.
#' @return A vector of coefficient estimates.
#' @export
coef.robust <- function(object, ...) return(object$coef)
