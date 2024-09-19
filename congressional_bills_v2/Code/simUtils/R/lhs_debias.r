#' Perform Debiasing Regression for Left-Hand-Side (LHS) Simulation
#'
#' This function estimates the error between two variables (Yllm and Yhuman) and performs a regression to debias the outcome (Ytilde).
#' @param train A data frame representing the training set, with columns Yllm, Yhuman, and V.
#' @param test A data frame representing the test set, with columns Yllm and V.
#' @param suppressWarnings Logical. If TRUE, suppresses warnings during model fitting.
#' @return A list containing:
#'   \item{coef_Ytilde_V}{Debiased coefficients from the regression of Ytilde on V.}
#'   \item{other}{Intermediate regression, namely error ~ V.}
#' @importFrom stats coef
#' @export
lhs_debias <- function(train, test, suppressWarnings=FALSE){
  # Estimate error using train data and perform regression on error ~ V
  # if no Bayesian bootstrap weights are provided, don't perform weighted LS by setting w=1
  if (is.null(train$w) | is.null(test$w)){
    train$w = 1
    test$w = 1
  }
  train$error <- train$Yllm - train$Yhuman
  train_error_V <- robust(stats::lm(error ~ V, weights=train$w, data=train), "train_error_V", suppressWarnings=suppressWarnings)
  coef_error_V <- coef(train_error_V)
  
  # Prepare design matrix for test data
  V <- stats::model.matrix(~ V, data=test)
  
  # Predict Ytilde for test data
  test$Ytilde <- test$Yllm - V %*% as.matrix(coef_error_V, nrow=2)
  
  # Regress Ytilde ~ V and extract coefficients
  Ytilde_V <- stats::lm(Ytilde ~ V, weights=test$w, data=test) 
  
  return(list(
    coef_Ytilde_V=coef(Ytilde_V), 
    other=list(train_error_V)
  ))
}