# Figure: Normalized bias of the plug-in regression and bias-corrected regression using policy topic as a covariate across Monte Carlo simulations based on congressional legislation.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures")

# Data and figure paths
data_path <- file.path(repo_dir, "congressional_bills/Data/Estimation/rhs_5k_llm_human_debiased_averaged.csv")
fig_path <- file.path(fig_dir, "fig_normalized_bias_cb_rhs_prop10.jpeg")
fig_width <- 9
fig_height <- 4

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
require(lemon, warn.conflicts = FALSE)
source(file.path(fig_dir, "ggplot_theme.r"))

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
    proportion==0.1,
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
  facet_grid(. ~ model)

# Add theme and aesthetics
fig <- fig + 
  labs(
    x = "Normalized Bias",
    y = "Probability Densities",
    color = NULL,
    fill = NULL
  ) +
  scale_color_manual(values=my_colors) +
  scale_fill_manual(values=alpha(my_colors, 0.3)) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar +
  theme(panel.spacing = unit(0.5, "cm", data = NULL))

# Save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))
