# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/RHS")
fig_dir <- file.path(repo_dir, "Figures")

dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

path_data_llm <- file.path(data_dir, "rhs_10k_llm.csv")
path_data_human <- file.path(data_dir, "rhs_10k_human.csv")
path_data_5k <- file.path(data_dir, "rhs_5k_llm_human_debiased_averaged.csv")

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
require(latex2exp, warn.conflicts = FALSE)
require(lemon, warn.conflicts = FALSE)
source(file.path(repo_dir, "Code/ggplot_theme.r"))

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
Y_levels <- c(3, 14, 15, 19, 20, "Other")
Y_labels <- c( "Health", "Banking, Finance & Domestic Commerce", "Defense", "Government Operations", "Public Lands & Water Management", "Other")
names(Y_levels) <- Y_labels
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13", "Validation")
model_labels <- c("GPT-3.5", "GPT-4o", "Validation")
regression_levels <- c("5k_V_Yllm", "train_V_Yhuman", "alpha_star")
regression_labels <- c("Plug-In", "Validation", "Debiased")
proportion_labeller <- labeller(
  proportion = function(proportion) sprintf("Validation Proportion = %s%%", as.numeric(proportion)*100)
)

# Load LLM Data
data_llm <- read.csv(path_data_llm) %>%
  mutate(
    model = factor(model, levels=model_levels, labels=model_labels),
    V = factor(V, levels=V_levels),
    Y = factor(coef_name, levels=Y_levels, labels=Y_labels)
  ) %>%
  filter(coef_name!="Other")

# Load Human Data
data_human <- read.csv(path_data_human) %>%
  mutate(
    model = factor("Validation", levels=model_levels, labels=model_labels),
    V = factor(V, levels=V_levels),
    Y = factor(coef_name, levels=Y_levels, labels=Y_labels)
  ) %>%
  filter(coef_name!="Other")

# Load averaged simulation data
data_5k <- read.csv(path_data_5k) %>%
  mutate(
    bias_norm = bias_mean/coef_sd, 
    V = factor(V, levels=V_levels),
    Y = factor(coef_name, levels=Y_levels, labels=Y_labels),
    model = factor(model, levels=model_levels, labels=model_labels),
    regression = factor(regression, levels=regression_levels, labels=regression_labels)
  ) %>%
  rename(proportion=train_proportion) %>%
  filter(
    coef_name!="Other",
    proportion==0.1
  )

# Figure 2: t-score vs Prompt-Model (Sorted)
# sort prompts by t-score
data_fig02 <- data_llm %>%
  group_by(V, coef_name) %>%
  arrange(V, coef_name, t) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# plot
fig02 <- data_fig02 %>%
  ggplot(aes(x=prompt.sorted, color=model, shape=model)) +
  geom_point(aes(y=t), size=1.25) +
  
  # theme and aesthetics
  xlab("Prompt-Model Index (Sorted)") +
  ylab("t-scores") +
  facet_grid(V ~ Y, labeller=label_wrap_gen(width=20), scales="free_y") +
  scale_color_manual(name=NULL, values=my_colors) +
  # merge color and shape legends
  guides(color = guide_legend(override.aes = list(
    # choose two shapes only since we're only plotting GPT-3.5 and GPT-4o
    shape = c(16, 17) 
  )), shape = "none") +
  theme.point

# save figure
fig_path = file.path(fig_dir, "figA07_cb_rhs_tscores.jpeg")
ggsave(fig_path, plot = fig02, height = 4.5, width = 9)
cat(sprintf("Saved %s\n", fig_path))

n_bins <- 64

# Figure 6: Normalized Bias Density by Model, Val Prop 10
fig06 <- data_5k %>%
  filter(regression != "Validation") %>%
  ggplot(aes(
    x=bias_norm, 
    y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]),
    color=regression, 
    fill=regression
  )) +
  geom_histogram(bins=n_bins, position="identity", alpha=0.3) +
  
  # theme and aesthetics
  xlab("Normalized Bias") +
  ylab("Probability Densities") +
  facet_grid(~ model) +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar +
  theme(panel.spacing = unit(0.5, "cm", data = NULL))

# save figure
fig_path = file.path(fig_dir, "figA08_cb_rhs_normalized_bias_prop10.jpeg")
ggsave(fig_path, plot = fig06, height = 4, width = 9)
cat(sprintf("Saved %s\n", fig_path))

# Figure 8: MSE CDF by Model, Val Prop 10
fig08 <- data_5k %>%
  filter(regression != "Plug-In") %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  facet_grid(~ model) +
  scale_x_continuous(minor_breaks = seq(0,1,0.002)) +
  coord_cartesian(xlim=c(0,0.04)) +
  scale_color_manual(name=NULL, values=alpha(my_colors, c(1,1,1,1,1,0.8))) +
  scale_linetype_manual(name=NULL, values=c("dashed", "solid")) +
  theme.mse  +
  theme(panel.spacing = unit(0.5, "cm", data = NULL))

# save figure
fig_path = file.path(fig_dir, "figA09_cb_rhs_mse_prop10.jpeg")
ggsave(fig_path, plot = fig08, height = 4, width = 9)
cat(sprintf("Saved %s\n", fig_path))

