# Figure: Cumulative distribution function of mean square error for the bias-corrected estimator against validation-sample only estimator using policy topic as a covariate.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/cb")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "estimation_cb/Data/rhs_5k_llm_human_debiased_averaged.csv")
fig_path <- file.path(fig_dir, "fig_mse_cb_rhs_prop05.jpeg")
fig_width <- 9
fig_height <- 4

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
require(lemon, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o"
)
regression_labels_levels <- c(
  "5k_V_Yllm"="Plug-In", 
  "train_V_Yhuman"="Validation", 
  "alpha_star"="Debiased"
)

# Load and format data
data <- read.csv(data_path) %>%
  mutate(
    bias_norm = bias_mean/coef_sd, 
    V = factor(V, levels=V_levels),
    model = recode_factor(model, !!!model_labels_levels),
    regression = recode_factor(regression, !!!regression_labels_levels)
  ) %>%
  rename(proportion=train_proportion) %>%
  filter(
    coef_name!="Other",
    proportion==0.05,
    regression!="Plug-In"
  )

# Plot figure
fig <- data %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  facet_grid(. ~ model)

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

# save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))