# Figure: Variation in t-statistics across large language models and prompting strategies on congressional legislation.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/estimation_cb")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "estimation_cb/Data/lhs_10k_plugin.csv")
fig_path <- file.path(fig_dir, "fig_tscores_cb_lhs.jpeg")
fig_width <- 9
fig_height <- 4.5

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
W_levels <- c("Democrat", "Senate", "DW1")
V_levels <- c(
  "Health", 
  "Banking, Finance & Domestic Commerce", 
  "Defense", 
  "Government Operations", 
  "Public Lands & Water Management"
)
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5-Turbo", 
  "gpt-4o-2024-05-13"="GPT-4o"
)

# Load and format data
data <- read.csv(data_path) %>%
  mutate(
    model = recode_factor(model, !!!model_labels_levels),
    W = factor(W, levels=W_levels),
    V = factor(V, levels=V_levels)
  ) %>%
  # sort prompts by t-score
  group_by(W, V) %>%
  arrange(t) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# Plot figure
fig <- data %>%
  ggplot(aes(x=prompt.sorted, y=t, color=model, shape=model)) +
  geom_point(size=1.25) +
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
  guides(color = guide_legend(override.aes = list(size=2)))

# Save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))
