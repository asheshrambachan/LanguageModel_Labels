# Setup directories
repo_dir <- "."
data_dir <- file.path(repo_dir, "Data/Estimation/LHS")
fig_dir <- file.path(repo_dir, "Figures/Estimation/LHS")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

path_data_llm <- file.path(data_dir, "lhs_10k_llm.csv")
path_data_human <- file.path(data_dir, "lhs_10k_human.csv")

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path("./Code/ggplot_theme.r"))

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13", "Human")
model.labels <- c("GPT-3.5", "GPT-4o", "Human")
Y_levels <- c(3, 14, 15, 19, 20)
Y_labels <- c( "Health", "Banking, Finance, and Domestic Commerce", "Defense", "Government Operations", "Public Lands and Water Management")

# Load LLM Data
data_llm <- read.csv(path_data_llm) %>%
  mutate(
    model = factor(model, levels=model_levels, labels=model.labels),
    V = factor(V, levels=V_levels),
    Y = factor(Y, levels=Y_levels, labels=Y_labels)
  ) %>%
  filter(coef_name!="(Intercept)")

# Load Human Data
data_human <- read.csv(path_data_human) %>%
  mutate(
    model = factor("Human", levels=model_levels, labels=model.labels),
    V = factor(V, levels=V_levels),
    Y = factor(Y, levels=Y_levels, labels=Y_labels)
  ) %>%
  filter(coef_name!="(Intercept)")

# Figure 2: t-score vs Prompt-Model (Sorted)
# sort prompts by t-score
data.fig02 <- data_llm %>%
  group_by(V, Y, coef_name) %>%
  arrange(V, Y, coef_name, t) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# plot
data.fig02 %>%
  ggplot(aes(x=prompt.sorted, color=model, shape=model)) +
  geom_hline(yintercept=0, color=my_palette[["black"]], linewidth=0.2) + # x-axis
  
  geom_point(aes(y=t), size=1.25, alpha=0.7, position=position_dodge(width=0.5)) +
  
  xlab("Prompt-Model Index (Sorted)") +
  ylab("t-scores") +
  
  # theme and aesthetics
  facet_grid(V ~ Y, labeller=label_wrap_gen(width=30)) +
  scale_color_manual(name=NULL, values=my_colors) +
  # merge color and shape legends
  guides(color = guide_legend(override.aes = list(
      # choose two shapes only since we're only plotting GPT-3.5 and GPT-4o
      shape = c(16, 17) 
    )), shape = "none") +
  theme.point

# save figure
fig_path = file.path(fig_dir, "fig02 t-score vs. Prompt-Model (Sorted).jpeg")
ggsave(fig_path, height = 5.5, width = 9)
cat(sprintf("Saved %s\n", fig_path))