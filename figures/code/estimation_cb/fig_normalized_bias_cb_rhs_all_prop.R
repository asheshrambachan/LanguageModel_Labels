# Figure: Normalized bias of the plug-in regression and bias-corrected regression using policy topic as a covariate across Monte Carlo simulations based on congressional legislation as the validation sample size varies.
# Dec 12, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/estimation_cb")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "estimation_cb/Data/rhs_5k_plugin_validation_debiased_averaged.csv")
fig_path <- file.path(fig_dir, "fig_normalized_bias_cb_rhs_all_prop.jpeg")
fig_width <- 9
fig_height <- 4

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
require(lemon, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
regression_levels <- c("Plug-In", "Validation", "Debiased")
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5-Turbo", 
  "gpt-4o-2024-05-13"="GPT-4o"
)
proportion_labels_levels <- c(
  `0.025`="2.5% Validation Prop.", 
  `0.05`="5% Validation Prop.", 
  `0.10`="10% Validation Prop.", 
  `0.25`="25% Validation Prop.",
  `0.50`="50% Validation Prop."
)

# Load and format data
data <- read.csv(data_path) %>%
  mutate(
    regression = factor(regression, regression_levels),
    model = recode_factor(model, !!!model_labels_levels),
    proportion = recode_factor(proportion, !!!proportion_labels_levels)
  ) %>%
  filter(
    regression!="Validation"
  )

# Plot figure
fig <- data %>%
  ggplot(aes(
    x=bias_norm, 
    y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]),
    color=regression, 
    fill=regression
  )) +
  geom_histogram(bins=64, position="identity") +
  facet_grid(model ~ proportion)

# Add theme and aesthetics
fig <- fig +
  labs(
    x = "Normalized Bias",
    y = "Probability Densities",
    color = NULL,
    fill = NULL
  ) +
  scale_fill_manual(values=alpha(my_colors, 0.3)) +
  scale_color_manual(values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar

# save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))