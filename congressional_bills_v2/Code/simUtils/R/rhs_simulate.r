#' Simulate Right-Hand-Side (RHS) Regressions Based on a Specified Combination
#'
#' This function performs simulations for RHS regressions based on specified combinations of variables and models. It uses bootstrap sampling to estimate uncertainty in the debiased coefficients.
#'
#' @param combination A list specifying the model and variables to use in the simulation.
#' @param data A data frame containing the full dataset.
#' @param N Integer. The number of simulations to perform.
#' @param B Integer. The number of bootstrap samples to generate.
#' @param n_samples Integer. The number of samples to draw for each simulation.
#' @param type_boot Character. Specifies the type of bootstrap ("bayesian" or "nonparametric").
#' @param rds_dir Optional character. If provided, the results will be saved as RDS files in the specified directory.
#' @return A data frame summarizing the results of all simulations or a path to the saved RDS file.
#' @export
rhs_simulate <- function(
    combination, 
    data,
    N,
    B,
    n_samples,
    type_boot = c("bayesian", "nonparametric"), 
    rds_dir = NULL){
  
  logger::log_appender(logger::appender_stdout)
  
  # Reformat and filter data based on the current combination
  # data <- data %>% 
  #   dplyr::filter(
  #     Model==combination$model, 
  #     Prompt==combination$prompt
  #   ) %>%
  #   dplyr::mutate(
  #     # Unlike LHS, we keep categorical variables as.integer as they are now used as the dependent variable
  #     V = .[[combination$variable]]
  #   )
  data <- data[(data$Model==combination$model) & (data$Prompt==combination$prompt), ]
  data$V <- data[[combination$variable]] # Unlike LHS, we keep categorical variables as.integer as they are now used as the dependent variable

  # On all 10K bills, 
  # (i) regress V ~ Yhuman
  V_Yhuman <- robust(stats::lm(V ~ Yhuman + 0, data), "10k_V_Yhuman")
  
  # (ii) regress V ~ Yllm
  V_Yllm <- robust(stats::lm(V ~ Yllm + 0, data), "10k_V_Yllm")
  
  # Initialize a data frame to log all regressions, starting with summary.V_Yhuman, and summary.V_Yllm
  regressions <- summary(list(V_Yhuman, V_Yllm))
  
  # Set seed to combination_id for reproducibility 
  set.seed(combination$combination_id)
  
  # N simulations (outer loop)
  for (i in (1:N)){ 
    log.prefix <- sprintf("[combination%04d sim_number%04d]", combination$combination_id, i)
    
    # Randomly draw n_samples observations with replacement
    data_sample <- data[sample(x=nrow(data), size=n_samples, replace=TRUE), ]
    
    # Split data into train and test sets based on the predefined train_proportion. Since data_sample is already a random sample, we don't need to randomize again.
    train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
    train <- data_sample[train_idx, ]
    
    rank_Yhuman <- Matrix::rankMatrix(stats::model.matrix(~ Yhuman + 0, data=train))[1]
    rank_Yllm <- Matrix::rankMatrix(stats::model.matrix(~ Yllm + 0, data=train))[1]
    while ((rank_Yhuman<6) | (rank_Yllm<6)){
      logger::log_warn("{log.prefix} Redraw data_sample because rank(Yhuman)={rank_Yhuman}<6 or rank(Yllm)={rank_Yllm}<6.")
      data_sample <- data[sample(x=nrow(data), size=n_samples, replace=TRUE), ]
      train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
      train <- data_sample[train_idx, ]
      
      rank_Yhuman <- Matrix::rankMatrix(stats::model.matrix(~ Yhuman + 0, data=train))[1]
      rank_Yllm <- Matrix::rankMatrix(stats::model.matrix(~ Yllm + 0, data=train))[1]
    }
    test <- data_sample[-train_idx, ] # %>% dplyr::select(!Yhuman)
    test[, "Yhuman"] <- NULL

    # On data_sample, regress Yllm ~ V
    V_Yllm <- robust(stats::lm(V ~ Yllm + 0, data_sample), "5k_V_Yllm")
    
    # (i) On train data, regress Yhuman ~ V (beta). Report robust standard errors
    # This is done and recorded in get_debiased_rhs().
    
    # (ii) Using train and test data, regress V_tilde ~ Ytilde, see get_debiased_rhs() for more details
    # Perform bootstrap on test_Ytilde_V to calculate standard errors and confidence intervals
    out <- withCallingHandlers(
      boot(
        fun = rhs_debias, 
        train = train, 
        test = test,
        B = B, 
        type_boot = type_boot, 
        fun_out_boot = c("coef_nu_Yllm", "coef_Vtilde_Ytilde")
      ),
      warning = function(w){
        logger::log_warn("{log.prefix} {conditionMessage(w)}")
        invokeRestart("muffleWarning")
      }
    )
    
    # Combine summaries for current iteration/sim_number, then append to all regressions 
    regressions <- dplyr::bind_rows(
      regressions, 
      summary(list(V_Yllm, out$coef_Vtilde_Ytilde, out$coef_nu_Yllm, out$other)) %>% 
        dplyr::mutate(sim_number=i, .before=1)) 
  }
  
  # Add metadata from the combination to all simulations
  regressions <- merge(combination, regressions, all=TRUE)
  
  # If rds_dir is provided, results will be saved as an RDS file; otherwise, they will be returned as a data.frame.
  if (is.null(rds_dir)){
    return(regressions)
  } else {
    # Set up Rds file output directory
    dir.create(rds_dir, showWarnings=FALSE, recursive = TRUE)
    path_regressions <- file.path(rds_dir, sprintf("combination%05d.rds", combination$combination_id))
    saveRDS(regressions, file=path_regressions)
    logger::log_info("Saved combination at {path_regressions}")
    return(data.frame(path=path_regressions))
  }
}
