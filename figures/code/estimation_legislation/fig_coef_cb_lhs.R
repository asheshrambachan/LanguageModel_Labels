# Figure: Variation in pairwise agreement between large language model labels across prompting strategies on congressional legislation.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/estimation_legislation")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
plugin_data_path <- file.path(repo_dir, "estimation_legislation/data/lhs_10k_plugin.csv")
validation_data_path <- file.path(repo_dir, "estimation_legislation/data/lhs_10k_validation.csv")
fig_path <- file.path(fig_dir, "fig_coef_cb_lhs.jpeg")
fig_width <- 9
fig_height <- 4.5

# Load packages
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
  "gpt-4o-2024-05-13"="GPT-4o",
  "gpt-5-mini"="GPT-5-mini",
  "gpt-5-nano"="GPT-5-nano",
  "Validation"="Validation"
)

# Load and format data
plugin_data <- read.csv(plugin_data_path) %>%
  mutate(
    model = factor(model, levels=names(model_labels_levels), labels=model_labels_levels),
    W = factor(W, levels=W_levels),
    V = factor(V, levels=V_levels)
  ) %>%
  # sort prompts by coef
  group_by(W, V) %>%
  arrange(coef) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

validation_data <- read.csv(validation_data_path) %>%
  mutate(
    model = "Validation",
    W = factor(W, levels=W_levels),
    V = factor(V, levels=V_levels)
  ) 

# Plot figure
fig <- plugin_data %>%
  ggplot(aes(x=prompt.sorted, color=model, shape=model)) +
  geom_errorbar(aes(ymin=lci, ymax=uci), width=0.5, linewidth=0.3) +
  geom_point(aes(y=coef), size=0.5) +
  facet_grid(W ~ V, labeller=label_wrap_gen(width=20)) +
  geom_hline(
    data=validation_data,
    mapping=aes(yintercept=coef, color=model), 
    linewidth=0.5
  ) 
    
# Add theme and aesthetics
fig <- fig +
  geom_hline(yintercept=0, color=my_palette[["black"]], linewidth=0.2, alpha=0.7) +
  labs(
    x = "Prompt-Model Index (Sorted)",
    y = "Coefficients",
    color = NULL,
    shape = NULL
  ) + 
  scale_color_manual(values=my_colors) +
  scale_shape_manual(values=my_shapes, drop=F) +
  theme.point

# Save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))
