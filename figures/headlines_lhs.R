# Financial news headlines across return types, models, prompting strategies, questions, mag/confidence/no_interaction

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"

# Data and figure paths
data_path <- list(
  file.path(repo_dir, "headlines/data/step9_reg_results/realized_returns_clustered.csv"),
  file.path(repo_dir, "headlines/data/step9_reg_results/abnormal_CAPM_returns_clustered.csv"),
  file.path(repo_dir, "headlines/data/step9_reg_results/abnormal_FF3_returns_clustered.csv"),
  file.path(repo_dir, "headlines/data/step9_reg_results/realized_returns_fe.csv")
)

out_dir <- file.path(repo_dir, "data")
out_data_path <- file.path(out_dir, "headlines_lhs.csv")
dir.create(out_dir, showWarnings=FALSE, recursive=TRUE)

# Load packages 
require(dplyr, warn.conflicts = FALSE)
require(logger, warn.conflicts = FALSE)

# Factor labels and levels
model_labels_levels <- c(
  "gpt-3.5-turbo"="GPT-3.5", 
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

out_data <- bind_rows(lapply(data_path, read.csv)) %>%
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
  mutate(
    t = coef / se,
    return_type = recode_factor(model, !!!return_labels_levels),
    model = recode_factor(model, !!!model_labels_levels),
    W = recode_factor(W, !!!W_labels_levels),
    V = if_else(question=="q1",
      recode_factor(V, !!!V_labels_levels_q1),
      recode_factor(V, !!!V_labels_levels_other_q)
    )
  ) %>%
  select(return_type, question, mag_v_conf, model, prompt, W, V, coef, se, t)

write.csv(out_data, file=out_data_path, row.names=FALSE)
log_info("Saved {out_data_path}")

