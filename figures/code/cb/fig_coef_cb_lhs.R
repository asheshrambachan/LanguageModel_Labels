# Figure: Variation in pairwise agreement between large language model labels across prompting strategies on congressional legislation.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/cb")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_llm_path <- file.path(repo_dir, "cb_estimation/Data/lhs_10k_llm.csv")
data_human_path <- file.path(repo_dir, "cb_estimation/Data/lhs_10k_human.csv")
fig_path <- file.path(fig_dir, "fig_coef_cb_lhs.jpeg")
fig_width <- 9
fig_height <- 4.5

# Load packages
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o",
  "Validation"="Validation"
)
Y_labels_levels <- c(
  `3` ="Health", 
  `14`="Banking, Finance & Domestic Commerce", 
  `15`="Defense", 
  `19`="Government Operations", 
  `20`="Public Lands & Water Management"
)

# Load and format data
data_llm <- read.csv(data_llm_path) %>%
  mutate(
    model = factor(model, levels=names(model_labels_levels), labels=model_labels_levels),
    V = factor(V, levels=V_levels),
    Y = recode_factor(Y, !!!Y_labels_levels)
  ) %>%
  filter(coef_name!="(Intercept)") %>%
  select(!c(regression, coef_name)) %>% 
  
  # sort prompts by coef
  group_by(V, Y) %>%
  arrange(V, Y, coef) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# Load Human Data
data_human <- read.csv(data_human_path) %>%
  mutate(
    model = "Validation",
    V = factor(V, levels=V_levels),
    Y = recode_factor(Y, !!!Y_labels_levels)
  ) %>%
  filter(coef_name!="(Intercept)") %>%
  select(!c(regression, coef_name))

# Plot figure
fig <- data_llm %>%
  ggplot(aes(x=prompt.sorted, color=model, shape=model)) +
  geom_errorbar(aes(ymin=lci, ymax=uci), width=0.5, linewidth=0.3) +
  geom_point(aes(y=coef), size=1.25) +
  facet_grid(V ~ Y, labeller=label_wrap_gen(width=20)) +
  geom_hline(
    data=data_human,
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

# save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))
