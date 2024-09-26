# Setup directories
data_dir = "./Data"
fig_dir = "./Figures and Tables/4.3_lhs_results/"
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Load packages
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
require(latex2exp, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)
require(lemon, warn.conflicts = FALSE)

# Load ggplot themes
source(file.path("./Code/ggplot_theme.r"))

# Factor labels and levels
V.levels <- c("Democrat", "Senate", "DW1")
model.levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13", "Human")
model.labels <- c("GPT-3.5", "GPT-4o", "Human")
Y.levels <- c(3, 14, 15, 19, 20)
Y.labels <- c( "Health", "Banking, Finance, and Domestic Commerce", "Defense", "Government Operations", "Public Lands and Water Management")

# Load LLM Data
data.llm <- read.csv(file.path(data_dir, "lhs_10k_llm.csv")) %>%
  mutate(
    model = factor(model, levels=model.levels, labels=model.labels),
    V = factor(V, levels=V.levels),
    Y = factor(Y, levels=Y.levels, labels=Y.labels)
  ) %>%
  filter(coef_name!="(Intercept)")

# Load Human Data
data.human <- read.csv(file.path(data_dir, "lhs_10k_human.csv")) %>%
  mutate(
    model = factor("Human", levels=model.levels, labels=model.labels),
    V = factor(V, levels=V.levels),
    Y = factor(Y, levels=Y.levels, labels=Y.labels)
  ) %>%
  filter(coef_name!="(Intercept)")

# Figure 1: Coef vs Prompt-Model (Sorted)
# sort prompts by coef
data.fig01 <- data.llm %>%
  group_by(V, Y, coef_name) %>%
  arrange(V, Y, coef_name, coef) %>% # arrange(V, Y, coef_name, t) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# plot
data.fig01 %>%
  ggplot(aes(x=prompt.sorted, color=model, shape=model)) +
  geom_hline(yintercept=0, color=my_palette[["black"]], linewidth=0.2) + # x-axis
  geom_errorbar(aes(ymin=lci, ymax=uci), position=position_dodge(width=0.5), width=0.5, linewidth=0.3) +
  geom_point(aes(y=coef), size=1.25, alpha=0.7, position=position_dodge(width=0.5)) +
  geom_hline(aes(yintercept=coef, color=model), linewidth=0.5, data=data.human) +
  
  xlab("Prompt-Model Index (Sorted)") +
  ylab("Coefficients") +
  
  # theme and aesthetics
  facet_grid(V ~ Y, labeller=label_wrap_gen(width=30)) +
  scale_color_manual(name=NULL, values=my_colors, labels=model.labels) +
  # merge color and shape legends
  guides(color = guide_legend(override.aes = list(
      # 'Human' is represented by a geom_hline (not a geom_point), 
      # so we set its shape to NA. The order of shapes in the list 
      # corresponds to the plotting order (e.g., geom_point followed by geom_hline).
      shape = c(16, 17, NA)) 
    ), shape = "none") +
  theme.point

# save figure
fig_path = file.path(fig_dir, "lhs_fig01_coef Coef vs Coef vs. Prompt-Model (Sorted).jpeg")
ggsave(fig_path, height = 5.5, width = 9)
cat(sprintf("Saved %s\n", fig_path))

# Figure 2: t-score vs Prompt-Model (Sorted)
# sort prompts by t-score
data.fig02 <- data.llm %>%
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
fig_path = file.path(fig_dir, "lhs_fig02_coef t-score vs Coef vs. Prompt-Model (Sorted).jpeg")
ggsave(fig_path, height = 5.5, width = 9)
cat(sprintf("Saved %s\n", fig_path))