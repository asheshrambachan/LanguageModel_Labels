# Figure: Cumulative distribution function of mean square error for the bias-corrected estimator against validation-sample only estimator using policy topic as a covariate.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/estimation_legislation")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "estimation_legislation/data/rhs_5k_plugin_validation_debiased_averaged.csv")
fig_path <- file.path(fig_dir, "fig_mse_cb_rhs_prop10.jpeg")
fig_width <- 9
fig_height <- 7

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
require(lemon, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
regression_levels <- c("Plug-In", "Validation", "Debiased")
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5-Turbo", 
  "gpt-4o-2024-05-13"="GPT-4o",
  "gpt-5-mini"="GPT-5-mini",
  "gpt-5-nano"="GPT-5-nano"
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
    regression!="Plug-In",
    proportion=="10% Validation Prop."
  )

# Plot figure
fig <- data %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  facet_wrap(. ~ model, ncol=2)

# Add theme and aesthetics
fig <- fig + 
  labs(
    x = "MSE",
    y = "Empirical CDF",
    color = NULL,
    linetype = NULL
  ) +
  scale_color_manual(values=my_colors) +
  scale_linetype_manual(values=my_linetype) +
  scale_x_continuous(minor_breaks = seq(0,1,0.001)) +
  coord_cartesian(xlim=c(0,0.022)) +
  theme.mse +
  theme(panel.spacing = unit(0.5, "cm", data = NULL))

# Save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))