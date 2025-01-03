# Figure: Variation in t-statistics for realized returns across large language models and prompting strategies on financial news headlines, q1, confidence, 5 and 10 days
# Dec 12, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/estimation_headlines")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "estimation_headlines/data/step9_reg_results/merged_data.csv")
fig_path <- file.path(fig_dir, "fig_tscores_headlines_realized_q1_confidence_5_10_day.jpeg")
fig_width <- 9
fig_height <- 4.5

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

data <- read.csv(data_path) %>% 
  filter(
    return_type == "Realized Returns",
    question == "q1",
    mag_v_conf == "confidence",
    W != "1 day"
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