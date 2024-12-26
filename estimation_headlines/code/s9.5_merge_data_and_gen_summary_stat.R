# Dec 17, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/estimation_headlines")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- list(
  file.path(repo_dir, "headlines/data/step9_reg_results/realized_returns_clustered.csv"),
  file.path(repo_dir, "headlines/data/step9_reg_results/abnormal_CAPM_returns_clustered.csv"),
  file.path(repo_dir, "headlines/data/step9_reg_results/abnormal_FF3_returns_clustered.csv"),
  file.path(repo_dir, "headlines/data/step9_reg_results/realized_returns_fe.csv")
)
merged_data_path <- file.path(repo_dir, "headlines/data/step9_reg_results/merged_data.csv")
summary_stat_path <- file.path(repo_dir, "headlines/data/step9_reg_results/summary_stat_data.csv")

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
model_labels_levels <- c(
  "gpt-3.5-turbo"="GPT-3.5-Turbo", 
  "gpt-4o"="GPT-4o",
  "gpt-4o-mini"="GPT-4o-mini"
)
return_labels_levels <- c(
  "realized" = "Realized Returns",
  "realized_fe" = "Realized Returns (Company and Date Fixed Effects)",
  "abnormal_CAPM" = "Abnormal Returns (CAPM)",
  "abnormal_FF3" = "Abnormal Returns (FF3)"
)
W_labels_levels <- c(
  `1` = "1 day",
  `5` = "5 days", 
  `10` = "10 days"
)
V_labels_levels_q1 <- c(
  "up" = "Positive", 
  "down" = "Negative"
)
V_labels_levels_other_q <- c(
  "up" = "Increase", 
  "down" = "Decrease"
)
q_labels_levels <- c(
  "q1" = "Q1 Positive, Negative, or Neutral?", 
  "q2" = "Q2 Increase, Decrease, or Uncertain Change to Returns?",
  "q3" = "Q3 Increase, Decrease, or Uncertain Change to Returns at Time?",
  "q4" = "Q4 Increase, Decrease, or Uncertain Sentiment", 
  "q5" = "Q5 Increase, Decrease, or Uncertain Sentiment at Time"
)

# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)

merged_data <- bind_rows(lapply(data_path, read.csv)) %>%
  select(!X) %>%
  rename(
    W = ret,
    coef.up = up.coef, 
    se.up = up.se,
    coef.down = down.coef, 
    se.down = down.se 
  ) %>%
  tidyr::pivot_longer(
    cols = starts_with("coef.") | starts_with("se."),
    names_to = c(".value", "V"),
    names_pattern = "(.*)\\.(.*)"
  ) %>%
  mutate(t = coef / se) %>%
  select(return_type, question, mag_v_conf, model, prompt, W, V, coef, se, t, return)  %>%
  mutate(
    return_type = recode_factor(return_type, !!!return_labels_levels),
    model = recode_factor(model, !!!model_labels_levels),
    W = recode_factor(W, !!!W_labels_levels),
    V = if_else(question=="q1",
                recode_factor(V, !!!V_labels_levels_q1),
                recode_factor(V, !!!V_labels_levels_other_q))
  )

# Save file
write.csv(merged_data, merged_data_path, row.names=FALSE)
cat(sprintf("Saved %s\n", merged_data_path))

# Compute summary stat
summary_stat <- merged_data %>%
  group_by(return_type, question, mag_v_conf, V, W) %>%
  summarise(
    "Mean" = mean(coef),
    "Median" = median(coef),
    "SD" = sd(coef),
    "CI05" = quantile(coef, probs[1]),
    "CI95" = quantile(coef, probs[2]),
    "Sample Average" = mean(return),
    .groups = "drop"
  ) 

# Save file
write.csv(summary_stat, summary_stat_path, row.names=FALSE)
cat(sprintf("Saved %s\n", summary_stat_path))
