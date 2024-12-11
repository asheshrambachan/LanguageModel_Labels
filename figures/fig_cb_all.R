# Generate LHS figures and tables
repo_dir <- "~/Documents/LanguageModel_Labels"
setwd(repo_dir)

cat("Generating figures...\n")

source("./figures/fig_tscores_cb_lhs.R")
source("./figures/fig_tscores_cb_lhs_blank.R")

source("./figures/fig_normalized_bias_cb_lhs_prop10.R")
source("./figures/fig_normalized_bias_cb_lhs_prop10.R")
source("./figures/fig_normalized_bias_cb_lhs_all_prop.R")

source("./figures/fig_mse_cb_lhs_prop10.R")
source("./figures/fig_mse_cb_lhs_prop10_blank.R")
source("./figures/fig_mse_cb_lhs_all_prop.R")


# source("./Code/Figures/fig01_cb_completion_exact_gpt4o_without_date.R")
# source("./Code/Figures/figA01_cb_completion_exact_gpt4o_with_date.R")
# source("./Code/Figures/fig02_headlines_completion_exact_gpt4o_without_date.R")
# source("./Code/Figures/figA02_headlines_completion_exact_gpt4o_with_date.R")
# 
# source("./Code/Figures/figA04_cb_llm_agreement_heatmaps.R")
# 
# 
# source("./Code/Figures/fig_cb_lhs_coef.R")
# 
# source("./Code/Figures/fig05_cb_lhs_tscores.R")
# source("./Code/Figures/fig05_cb_lhs_tscores_blank.R")
# 
# source("./Code/Figures/fig06_cb_llm_accuracy.R")
# source("./Code/Figures/fig06_cb_llm_accuracy_blank.R")
# 
# source("./Code/Figures/figA05_cb_lhs_normalized_bias_all_prop.R")
# source("./Code/Figures/fig07_cb_lhs_normalized_bias_prop10.R")
# source("./Code/Figures/fig07_cb_lhs_normalized_bias_prop10_blank.R")
# 
# source("./Code/Figures/figA06_cb_lhs_mse_all_prop.R")
# source("./Code/Figures/fig08_cb_lhs_mse_prop10.R")
# source("./Code/Figures/fig08_cb_lhs_mse_prop10_blank.R")
# 




