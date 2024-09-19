#' Create a Robust Data Object
#'
#' This function creates a robust data object from a linear model.
#' @param model A linear model object.
#' @param regression_name A name for the regression model.
#' @param suppressWarnings A logical value to suppress warnings.
#' @return A robust object.
#' @export
robust <- function(model, regression_name, suppressWarnings=F){ 
  if(any(se(model)==0)){
    msg <- sprintf("%s essentially perfect fit: summary may be unreliable", regression_name)
    if(!suppressWarnings) warning(simpleWarning(msg))
  }
  
  # Calculate robust standard errors
  model_robust <- withCallingHandlers(
    expr = lmtest::coeftest(model, vcov=sandwich::vcovHC(model, type="HC1")),
    warning = function(w){
      msg <- sprintf("%s %s", regression_name, conditionMessage(w))
      if(!suppressWarnings) warning(simpleWarning(msg))
      invokeRestart("muffleWarning")
    }
  )
  
  # Simplify coefficient names
  rownames(model_robust) <- gsub("Yhuman|Yllm|Ytilde", "", rownames(model_robust))
  rownames(model_robust) <- gsub("V1", "V", rownames(model_robust))
  
  return(structure(
    list(
      regression_name = regression_name,
      df.residual = attr(model_robust, "df"),
      coef = model$coef,
      coef_name = rownames(model_robust),
      coef_vec = model_robust[, "Estimate"], #model$coef,
      se = model_robust[, "Std. Error"],
      t_stat = model_robust[, "t value"]
    ),
    class = "robust"
  ))
}