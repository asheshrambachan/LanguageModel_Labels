# Figure: Variation in t-statistics for realized returns across large language models and prompting strategies on financial news headlines, q2, confidence, 1 day
# Dec 12, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures")

# Data and figure paths
data_path <- file.path(repo_dir, "headlines/data/step9_reg_results/realized_returns_clustered.csv")
fig_path <- file.path(fig_dir, "fig_tscores_headlines_realized_q2_confidence_1_day.jpeg")
fig_width <- 9
fig_height <- 4

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(fig_dir, "ggplot_theme.r"))

# Factor labels and levels
model_labels_levels <- c(
  "gpt-3.5-turbo"="GPT-3.5", 
  "gpt-4o"="GPT-4o",
  "gpt-4o-mini"="GPT-4o-mini"
)
V_labels_levels <- c(
  `1` = "1 day",
  `5` = "5 days", 
  `10` = "10 days"
)
Y_labels_levels <- c(
  "up" = "Increase", 
  "down" = "Decrease"
)

data <- read.csv(data_path) %>%
  rename(V = ret) %>% 
  filter(
    return_type == "realized",
    question == "q2",
    mag_v_conf == "confidence",
    V == 1
  ) %>%
  rename(
    coef.up = up.coef, 
    se.up = up.se,
    coef.down = down.coef, 
    se.down = down.se 
  ) %>%
  select(model, V, coef.up, se.up, coef.down, se.down) %>%
  tidyr::pivot_longer(
    cols = starts_with("coef.") | starts_with("se."),
    names_to = c(".value", "Y"),
    names_pattern = "(.*)\\.(.*)"
  ) %>%
  mutate(
    t = coef / se,
    model = recode_factor(model, !!!model_labels_levels),
    V = recode_factor(V, !!!V_labels_levels),
    Y = recode_factor(Y, !!!Y_labels_levels)
  ) %>%
  group_by(Y, V) %>%
  arrange(V, Y, t) %>%
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# Plot figure
fig <- data %>%
  ggplot(aes(x=prompt.sorted, y=t, color=model, shape=model)) +
  geom_point(size=2) +
  facet_grid(V ~ Y, labeller=label_wrap_gen(width=20))

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