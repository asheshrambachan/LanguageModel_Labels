#' Simulate Left-Hand-Side (LHS) Regressions Based on a Specified Combination
#'
#' This function performs simulations for LHS regressions based on combinations of variables and models, performing bootstrap sampling to estimate uncertainty.
#' @param combination A list specifying the model and variables to use in the simulation.
#' @param data A data frame containing the full dataset.
#' @param N Integer. The number of simulations to perform.
#' @param B Integer. The number of bootstrap samples to generate.
#' @param n_samples Integer. The number of samples to draw for each simulation.
#' @param type_boot Character. Specifies the type of bootstrap ("bayesian" or "nonparametric").
#' @param rds_dir Optional character. If provided, the results will be saved as RDS files in the specified directory.
#' @return A data frame summarizing the results of all simulations or a path to the saved RDS file.
#' @importFrom dplyr %>%
#' @export
lhs_simulate <- function(
    combination, 
    data,
    N,
    B,
    n_samples,
    type_boot = c("bayesian", "nonparametric"), 
    rds_dir = NULL) {
  
  logger::log_appender(logger::appender_stdout)
  
  # Reformat and filter data based on the current combination
  # data <- data %>% 
  #   dplyr::filter(
  #     Model==combination$model, 
  #     Prompt==combination$prompt
  #   ) %>%
  #   dplyr::mutate(
  #     Senate = as.factor(Senate),
  #     Democrat = as.factor(Democrat),
  #     V = .[[combination$variable]],
  #     Yhuman = as.integer(Yhuman == combination$major_topic),
  #     Yllm = as.integer(Yllm == combination$major_topic)
  #   )
  data <- data[(data$Model==combination$model) & (data$Prompt==combination$prompt), ]
  data$Senate <- as.factor(data$Senate)
  data$Democrat <- as.factor(data$Democrat)
  data$V <- data[[combination$variable]]
  data$Yhuman <- as.integer(data$Yhuman == combination$major_topic)
  data$Yllm <- as.integer(data$Yllm == combination$major_topic)

  # On all 10K bills:
  # (i) regress Yhuman ~ V
  Yhuman_V <- robust(stats::lm(Yhuman ~ V, data=data), "10k_Yhuman_V", F)
  
  # (ii) regress Yllm ~ V
  Yllm_V <- robust(stats::lm(Yllm ~ V, data=data), "10k_Yllm_V")
  
  # Initialize a data frame to log all regressions, starting with Yhuman_V and Yllm_V
  regressions <- summary(list(Yhuman_V, Yllm_V))
  
  # Set seed to combination_id for reproducibility
  set.seed(combination$combination_id)
  
  # N simulations (outer loop)
  for (i in (1:N)){
    log.prefix <- sprintf("[combination%04d sim_number%04d]", combination$combination_id, i)
    
    # Randomly draw n_samples observations with replacement
    data_sample <- data[sample(x=nrow(data), size=n_samples, replace=TRUE), ]
    
    # On data_sample, regress Yllm ~ V
    Yllm_V <- robust(stats::lm(Yllm ~ V, data=data_sample), "5k_Yllm_V")
    
    # Split data into train and test sets based on the predefined train_proportion
    # Note: Since data_sample is already a random sample, we don't need to randomize again.
    train_idx <- 1:(nrow(data_sample) * combination$train_proportion)
    train <- data_sample[train_idx, ]
    test <- data_sample[-train_idx, ] # %>% dplyr::select(!Yhuman)
    test[, "Yhuman"] <- NULL
    
    # (i) On train data, regress Yhuman ~ V. Report robust standard errors
    Yhuman_V <- robust(stats::lm(Yhuman ~ V, data=train), "train_Yhuman_V")
    
    # (ii) Using train and test data, regress Ytilde ~ V, see debias.lhs() for more details
    # Perform bootstrap on test_Ytilde_V to calculate standard errors and confidence intervals
    out <- withCallingHandlers(
      boot(
        fun = lhs_debias,
        train = train,
        test = test,
        B = B,
        type_boot = type_boot,
        fun_out_boot = "coef_Ytilde_V"
      ),
      warning = function(w){
        logger::log_warn("{log.prefix} {conditionMessage(w)}")
        invokeRestart("muffleWarning")
      }
    )
    
    # Combine all summaries for current iteration/sim_number, then append to all regressions
    regressions <- dplyr::bind_rows(
      regressions,
      summary(list(Yllm_V, Yhuman_V, out$coef_Ytilde_V, out$other)) %>%
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
