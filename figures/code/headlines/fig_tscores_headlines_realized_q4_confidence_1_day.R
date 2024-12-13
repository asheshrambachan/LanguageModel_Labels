# Figure: Variation in t-statistics for realized returns across large language models and prompting strategies on financial news headlines, q4, confidence, 1 day
# Dec 12, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/headlines")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- list(
  file.path(repo_dir, "headlines/data/step9_reg_results/realized_returns_clustered.csv"),
  file.path(repo_dir, "headlines/data/step9_reg_results/abnormal_CAPM_returns_clustered.csv")
  # file.path(repo_dir, "headlines/data/step9_reg_results/abnormal_FF3_returns_clustered.csv"),
  # file.path(repo_dir, "headlines/data/step9_reg_results/realized_returns_fe.csv")
)
fig_path <- file.path(fig_dir, "fig_tscores_headlines_realized_q4_confidence_1_day.jpeg")
fig_width <- 9
fig_height <- 4

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

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

all_data <- bind_rows(lapply(data_path, read.csv)) %>%
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
  select(return_type, question, mag_v_conf, model, prompt, W, V, coef, se, t)

data <- all_data %>% 
  filter(
    return_type == "realized",
    question == "q4",
    mag_v_conf == "confidence",
    W == 1
  ) %>%
  mutate(
    return_type = recode_factor(return_type, !!!return_labels_levels),
    model = recode_factor(model, !!!model_labels_levels),
    W = recode_factor(W, !!!W_labels_levels),
    V = if_else(question=="q1",
                recode_factor(V, !!!V_labels_levels_q1),
                recode_factor(V, !!!V_labels_levels_other_q))
  ) %>%
  group_by(V, W) %>%
  arrange(W, V, t) %>%
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# Plot figure
fig <- data %>%
  ggplot(aes(x=prompt.sorted, y=t, color=model, shape=model)) +
  geom_point(size=2) +
  facet_grid(W ~ V, labeller=label_wrap_gen(width=20))

# Add theme and aesthetics
fig <- fig +
  geom_hline(yintercept=0, color=my_palette[["black"]], linewidth=0.2, alpha=0.7) + # x-axis
  labs(
    x = "Prompt-Model Index (Sorted)",
    y = "t-scores",
    color = NULL,
    shape = NULL
  ) +
  scale_color_manual(values = my_colors) +
  scale_shape_manual(values = my_shapes) +
  theme.point +
  theme(panel.spacing = unit(0.5, "cm", data = NULL))

# Save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))