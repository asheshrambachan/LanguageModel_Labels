repo_dir <- "~/Documents/LanguageModel_Labels"
setwd(repo_dir)

cat("Generating cb figures...\n")

source("./figures/fig_exact_completion_gpt4o_without_date_cb.R")
source("./figures/fig_exact_completion_gpt4o_with_date_cb.R")

source("./figures/fig_agreement_heatmaps_cb.R")

source("./figures/fig_tscores_cb_lhs.R")
source("./figures/fig_tscores_cb_rhs.R")
source("./figures/fig_tscores_cb_lhs_blank.R")

source("./figures/fig_coef_cb_lhs.R")
source("./figures/fig_coef_cb_rhs.R")

source("./figures/fig_llm_accuracy_cb.R")
source("./figures/fig_llm_accuracy_cb_blank.R")

source("./figures/fig_normalized_bias_cb_lhs_prop10.R")
source("./figures/fig_normalized_bias_cb_rhs_prop10.R")
source("./figures/fig_normalized_bias_cb_lhs_prop10_blank.R")

source("./figures/fig_normalized_bias_cb_lhs_all_prop.R")
source("./figures/fig_normalized_bias_cb_rhs_all_prop.R")

source("./figures/fig_mse_cb_lhs_prop10.R")
source("./figures/fig_mse_cb_rhs_prop10.R")
source("./figures/fig_mse_cb_lhs_prop10_blank.R")

source("./figures/fig_mse_cb_lhs_all_prop.R")
source("./figures/fig_mse_cb_rhs_all_prop.R")
