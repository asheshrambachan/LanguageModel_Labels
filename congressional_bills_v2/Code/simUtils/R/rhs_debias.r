#' Perform Debiasing Regression for Right-Hand-Side (RHS) Simulation
#'
#' This function performs a debiasing regression for RHS variables, regressing the variable of interest (Vtilde) on the predicted values (Ytilde).
#' The function calculates intermediate regressions and predicts debiased coefficients for the test data.
#'
#' @param train A data frame representing the training set, with columns V, Yhuman, Yllm, and possibly weights.
#' @param test A data frame representing the test set, with columns V, Yhuman, Yllm, and possibly weights.
#' @param suppressWarnings Logical. If TRUE, suppresses warnings during model fitting.
#' @return A list containing:
#'   \item{coef_nu_Yllm}{Coefficients from the regression of nu on Yllm.}
#'   \item{coef_Vtilde_Ytilde}{Debiased coefficients from the regression of Vtilde on Ytilde.}
#'   \item{other}{A list of intermediate regressions, including V ~ Yhuman, V ~ Yllm, and Yhuman ~ Yllm.}
#' @importFrom stats coef
#' @export
rhs_debias <- function(train, test, suppressWarnings=FALSE) {
  
  # (i) Train data
  # beta
  # if no Bayesian bootstrap weights are provided, don't perform weighted LS by keeping w=NULL
  if (is.null(train$w) | is.null(test$w)){
    train$w = 1
    test$w = 1
  }
  V_Yhuman <- robust(stats::lm(V ~ Yhuman + 0, weights=train$w, train), "train_V_Yhuman", suppressWarnings=suppressWarnings)
  coef_V_Yhuman <- coef(V_Yhuman)
  
  # delta_{V, \hat{Y}}
  V_Yllm <- robust(stats::lm(V ~ Yllm + 0, weights=train$w, train), "train_V_Yllm", suppressWarnings=suppressWarnings) 
  coef_V_Yllm <- coef(V_Yllm)
  
  # delta_{Y, \hat{Y}}
  sqrt_weights <- diag(sqrt(train$w))
  Yhuman <- sqrt_weights %*% stats::model.matrix(~ Yhuman + 0, data=train)
  Yllm <- sqrt_weights %*% stats::model.matrix(~ Yllm + 0, data=train)
  Yhuman_Yllm <- robust(stats::lm(Yhuman ~ Yllm + 0), "train_Yhuman_Yllm", suppressWarnings=suppressWarnings)
  coef_Yhuman_Yllm <- coef(Yhuman_Yllm) # 20*20, Yllm * Yhuman
  
  # delta_{nu, \hat{Y}} = delta_{V, \hat{Y}} - delta_{Y, \hat{Y}} beta
  coef_nu_Yllm <- coef_V_Yllm - as.vector(coef_Yhuman_Yllm %*% coef_V_Yhuman)
  
  # (ii) Test data
  Yllm <- stats::model.matrix(~ Yllm + 0, data=test)
  
  # Ytilde: predicted Yhuman
  Ytilde <- Yllm %*% coef_Yhuman_Yllm
  colnames(Ytilde) <- sub("human","tilde", colnames(Ytilde))
  
  # V_tilde
  test$V_tilde <- test$V - Yllm %*% coef_nu_Yllm 

  # Regress Vtilde ~ Ytilde
  formula <- sprintf("V_tilde ~ %s + 0", paste(colnames(Ytilde), collapse=" + "))
  Vtilde_Ytilde <- stats::lm(formula, weights=w, data=cbind(test, Ytilde))
  
  return(list(
    coef_nu_Yllm = coef_nu_Yllm, 
    coef_Vtilde_Ytilde = coef(Vtilde_Ytilde), 
    other = list( # return intermediate regressions
      V_Yhuman,
      V_Yllm,
      Yhuman_Yllm)
  ))
}
