#' Create a Bootstrap Data Object
#'
#' This function creates a bootstrap data object from a model-fitting function, using either nonparametric or Bayesian bootstrap methods.
#' @param fun A function that fits a model to training data and returns coefficients.
#' @param B The number of bootstrap samples to generate.
#' @param type_boot The type of bootstrap to perform ("bayesian" or "nonparametric").
#' @param fun_out_boot A vector of names indicating which elements of the function output to bootstrap.
#' @param train The training dataset.
#' @param test The test dataset.
#' @return A bootstrap object with the bootstrapped coefficient estimates.
#' @export
boot <- function(fun, train, test, B, type_boot=c("bayesian", "nonparametric"), fun_out_boot){
  type_boot <- match.arg(type_boot)
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
          regression_name = sub("coef_", "", var)),
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
    if (type_boot=="nonparametric"){
      train_boot <- train_boot[sample(x=nrow(train_boot), replace=TRUE), ]
      test_boot <- test_boot[sample(x=nrow(test_boot), replace=TRUE), ]
    } else if (type_boot=="bayesian") {
      w_train <- stats::rgamma(nrow(train_boot), shape=1, scale=1) 
      w_test <- stats::rgamma(nrow(test_boot), shape=1, scale=1)
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

