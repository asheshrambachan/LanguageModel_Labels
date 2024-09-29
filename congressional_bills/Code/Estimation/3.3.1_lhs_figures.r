# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/LHS")
fig_dir <- file.path(repo_dir, "Figures/Estimation/LHS")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

path_data_llm <- file.path(data_dir, "lhs_10k_llm.csv")
path_data_human <- file.path(data_dir, "lhs_10k_human.csv")
path_data_5k <- file.path(data_dir, "lhs_5k_llm_human_debiased_averaged.csv")

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
require(lemon, warn.conflicts = FALSE)
source(file.path(repo_dir, "Code/ggplot_theme.r"))

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13", "Human")
model_labels <- c("GPT-3.5", "GPT-4o", "Human")
Y_levels <- c(3, 14, 15, 19, 20)
Y_labels <- c( "Health", "Banking, Finance, and Domestic Commerce", "Defense", "Government Operations", "Public Lands and Water Management")
regression_levels <- c("5k_Yllm_V", "train_Yhuman_V", "Ytilde_V")
regression_labels <- c("LLM", "Human Validation", "Debiased")

# Load LLM Data
data_llm <- read.csv(path_data_llm) %>%
  mutate(
    model = factor(model, levels=model_levels, labels=model_labels),
    V = factor(V, levels=V_levels),
    Y = factor(Y, levels=Y_levels, labels=Y_labels)
  ) %>%
  filter(coef_name!="(Intercept)")

# Load Human Data
data_human <- read.csv(path_data_human) %>%
  mutate(
    model = factor("Human", levels=model_levels, labels=model_labels),
    V = factor(V, levels=V_levels),
    Y = factor(Y, levels=Y_levels, labels=Y_labels)
  ) %>%
  filter(coef_name!="(Intercept)")

# Load averaged simulation data
data_5k <- read.csv(path_data_5k) %>%
  mutate(
    bias_norm = bias_mean/coef_sd, 
    V = factor(V, levels=V_levels),
    model = factor(model, levels=model_levels, labels=model_labels),
    regression = factor(regression, levels=regression_levels, labels=regression_labels)
  ) %>%
  rename(proportion=train_proportion) %>%
  filter(coef_name!="(Intercept)")

# Figure 1:
# sort prompts by coef estimate
data_fig01 <- data_llm %>%
  group_by(V, Y, coef_name) %>%
  arrange(V, Y, coef_name, coef) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

fig01 <- data_fig01 %>%
  ggplot(aes(x=prompt.sorted, color=model, shape=model)) +
  geom_hline(yintercept=0, color=my_palette[["black"]], linewidth=0.2) +
  geom_errorbar(aes(ymin=lci, ymax=uci), width=0.5, linewidth=0.3) +
  geom_point(aes(y=coef), size=1.25, alpha=0.7) +
  geom_hline(aes(yintercept=coef, color=model), linewidth=0.5, data=data_human) +
  
  # theme and aesthetics
  xlab("Prompt-Model Index (Sorted)") +
  ylab("Coefficients") +
  facet_grid(V ~ Y, labeller=label_wrap_gen(width=30)) +
  scale_color_manual(name=NULL, values=my_colors, labels=model_labels) +
  guides(color = guide_legend(override.aes = list(shape = c(16, 17, NA))),
         shape = "none") +  # merge color and shape legends
  theme.point

# save figure
fig_path = file.path(fig_dir, "fig01 Coefficent vs. Prompt-Model (Sorted).jpeg")
ggsave(fig_path, plot = fig01, height = 5.5, width = 9)
cat(sprintf("Saved %s\n", fig_path))

# Figure 2: t-score vs Prompt-Model (Sorted)
# sort prompts by t-score
data_fig02 <- data_llm %>%
  group_by(V, Y, coef_name) %>%
  arrange(V, Y, coef_name, t) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# plot
fig02 <- data_fig02 %>%
  ggplot(aes(x=prompt.sorted, color=model, shape=model)) +
  geom_hline(yintercept=0, color=my_palette[["black"]], linewidth=0.2) + # x-axis
  geom_point(aes(y=t), size=1.25, alpha=0.7) +
  
  # theme and aesthetics
  xlab("Prompt-Model Index (Sorted)") +
  ylab("t-scores") +
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
ggsave(fig_path, plot = fig02, height = 5.5, width = 9)
cat(sprintf("Saved %s\n", fig_path))


# Figure 3: Bias Density of the LLM Coefficent
n_bins <- 30

fig03 <- data_5k %>%
  filter(
    proportion==0.05, 
    regression=="LLM"
  ) %>%
  ggplot(aes(x=bias_mean, y=after_stat(count/sum(count)), fill=regression)) +
  geom_vline(xintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  geom_histogram(bins=n_bins, color="white") +  
  geom_hline(yintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  
  # theme and aesthetics
  xlab("Bias") +
  ylab("Probability Densities") +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0, 1, by=0.01), limits=c(0,0.25)) +
  theme.bar + 
  guides(fill="none")

# save figure
fig_path = file.path(fig_dir, "fig03 Bias Density LLM.jpeg")
ggsave(fig_path, plot = fig03, height = 3.5, width = 4)
cat(sprintf("Saved %s\n", fig_path))


# Figure 4: Normalized Bias Density of the LLM Coefficent
fig04 <- data_5k %>%
  filter(
    proportion==0.05,
    regression=="LLM"
  ) %>%
  ggplot(aes(x=bias_norm, y=after_stat(count/sum(count)), fill=regression)) +
  geom_vline(xintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  geom_histogram(bins=n_bins, color="white") +
  geom_hline(yintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  
  # theme and aesthetics
  xlab("Normalized Bias") +
  ylab("Probability Densities") + 
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1,by=0.01), limits=c(0,0.25)) +
  theme.bar + 
  guides(fill="none")

# save figure
fig_path = file.path(fig_dir, "fig04 Normalized Bias Density LLM.jpeg")
ggsave(fig_path, plot = fig04, height = 3.5, width = 4)
cat(sprintf("Saved %s\n", fig_path))


# Figure 5: Bias Density by Model and Validation Proportion
facet.labeller <- labeller(
  proportion = function(proportion) sprintf("Validation Proportion = %s%%", as.numeric(proportion)*100)
)

fig05 <- data_5k %>%
  filter(
    proportion!=0.25,
    regression!="Human Validation"
  ) %>%
  ggplot(aes(
    x=bias_mean, 
    y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]), 
    group=regression, fill=regression
  )) +
  geom_histogram(bins=n_bins, position=position_dodge()) +
  
  # theme and aesthetics
  xlab("Bias") +
  ylab("Probability Densities") +
  facet_grid(model ~ proportion, labeller=facet.labeller) +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar

# save figure
fig_path = file.path(fig_dir, "fig05 Bias Density by Model and Validation Proportion.jpeg")
ggsave(fig_path, plot = fig05, height = 4.5, width = 8)
cat(sprintf("Saved %s\n", fig_path))


# Figure 6: Normalized Bias Density by Model and Validation Proportion
fig06 <- data_5k %>%
  filter(
    proportion!=0.25,
    regression!="Human Validation"
  ) %>%
  ggplot(aes(x=bias_norm, y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]),
             group=regression, fill=regression)) +
  geom_histogram(binwidth=0.09, position=position_dodge()) +
  
  # theme and aesthetics
  xlab("Normalized Bias") +
  ylab("Probability Densities") +
  facet_grid(model ~ proportion, labeller=facet.labeller) +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar

# save figure
fig_path = file.path(fig_dir, "fig06 Normalized Bias Density by Model and Validation Proportion.jpeg")
ggsave(fig_path, plot = fig06, height = 4.5, width = 8)
cat(sprintf("Saved %s\n", fig_path))


# Figure 7: MSE CDF by Validation Proportion
fig07 <- data_5k %>%
  filter(
    proportion != 0.25,
    regression != "LLM"
  ) %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  facet_grid(. ~ proportion, labeller=facet.labeller) +
  scale_x_continuous(minor_breaks = seq(0,1,0.0001)) +
  scale_color_manual(name="", values=my_colors) +
  scale_linetype_manual(name="", values=c("dashed", "solid")) +
  theme.mse

# save figure
fig_path = file.path(fig_dir, "fig07 MSE CDF by Validation Proportion.jpeg")
ggsave(fig_path, plot = fig07, height = 3, width = 8)
cat(sprintf("Saved %s\n", fig_path))


# Figure 8: MSE CDF by Model and Validation Proportion
fig08 <- data_5k %>%
  filter(
    proportion != 0.25,
    regression != "LLM"
  ) %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  facet_grid(model ~ proportion, labeller=facet.labeller) +
  scale_x_continuous(minor_breaks = seq(0,1,0.0001)) +
  scale_color_manual(name="", values=my_colors) +
  scale_linetype_manual(name="", values=c("dashed", "solid")) +
  theme.mse

# save figure
fig_path = file.path(fig_dir, "fig08 MSE CDF by Model and Validation Proportion.jpeg")
ggsave(fig_path, plot = fig08, height = 4.5, width = 8)
cat(sprintf("Saved %s\n", fig_path))
