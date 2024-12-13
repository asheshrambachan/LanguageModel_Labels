repo_dir <- "~/Documents/LanguageModel_Labels"
setwd(repo_dir)

cat("Generating headlines figures...\n")

source("./figures/fig_exact_completion_gpt4o_without_date_headlines.R")
source("./figures/fig_exact_completion_gpt4o_with_date_headlines.R")

source("./figures/fig_agreement_heatmaps_headlines_realized_q1.R")

source("./figures/fig_tscores_headlines_realized_q1_magnitude_all_days.R")
source("./figures/fig_tscores_headlines_realized_q1_confidence_all_days.R")

source("./figures/fig_tscores_headlines_realized_q2_confidence_1_day.R")
source("./figures/fig_tscores_headlines_realized_q4_confidence_1_day.R")
source("./figures/fig_tscores_headlines_realized_q2_confidence_1_day_blank.R")

source("./figures/fig_tscores_headlines_realized_q2_confidence_5_10_day.R")
source("./figures/fig_tscores_headlines_realized_q4_confidence_5_10_day.R")

source("./figures/fig_tscores_headlines_abnormal_q2_confidence_1_day.R")
source("./figures/fig_tscores_headlines_abnormal_q4_confidence_1_day.R")