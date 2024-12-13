# Figure: Variation in t-statistics across large language models and prompting strategies on congressional legislation, using the economic concept as a covariate.
# Dec 12, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures")

# Data and figure paths
data_path <- file.path(repo_dir, "congressional_bills/Data/Estimation/rhs_10k_llm.csv")
fig_path <- file.path(fig_dir, "fig_tscores_cb_rhs.jpeg")
fig_width <- 9
fig_height <- 4.5

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(fig_dir, "ggplot_theme.r"))

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
Y_labels_levels <- c(
  `3` ="Health", 
  `14`="Banking, Finance & Domestic Commerce", 
  `15`="Defense", 
  `19`="Government Operations", 
  `20`="Public Lands & Water Management"
)
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o"
)

# Load and format data
data <- read.csv(data_path) %>%
  mutate(
    model = recode_factor(model, !!!model_labels_levels),
    V = factor(V, levels=V_levels),
    Y = recode_factor(coef_name, !!!Y_labels_levels)
  ) %>%
  filter(coef_name!="Other") %>%
  select(!c(regression, coef_name)) %>% 
  
  # sort prompts by t-score
  group_by(V, Y) %>%
  arrange(V, Y, t) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# Plot figure
fig <- data %>%
  ggplot(aes(x=prompt.sorted, y=t, color=model, shape=model)) +
  geom_point(size=1.25) +
  facet_grid(V ~ Y, labeller=label_wrap_gen(width=20), scales="free_y")

# Add theme and aesthetics
fig <- fig +
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
