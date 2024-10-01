# Setup directories
# repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
repo_dir <- "."
data_dir <- file.path(repo_dir, "Data/Estimation/RHS")
fig_dir <- file.path(repo_dir, "Figures/Estimation/RHS")
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
Y_labels <- c( "Health", "Banking, Finance, and Domestic Commerce", "Defense", "Government Operations", "Public Lands and Water Management", "Other")
names(Y_levels) <- Y_labels
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13", "Human")
model_labels <- c("GPT-3.5", "GPT-4o", "Human")
regression_levels <- c("5k_V_Yllm", "train_V_Yhuman", "Vtilde_Ytilde")
regression_labels <- c("LLM", "Human Validation", "Debiased")

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
    model = factor("Human", levels=model_levels, labels=model_labels),
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
  filter(coef_name!="Other")

# Figure 1:
# sort prompts by coef estimate
data_fig01 <- data_llm %>%
  group_by(V, coef_name) %>%
  arrange(V, coef_name, coef) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

fig01 <- data_fig01 %>%
  ggplot(aes(x=prompt.sorted, color=model, shape=model)) +
  geom_errorbar(aes(ymin=lci, ymax=uci), width=0.5, linewidth=0.3) +
  geom_point(aes(y=coef), size=1.25, alpha=0.7) +
  geom_hline(aes(yintercept=coef, color=model), linewidth=0.5, data=data_human) +
  
  # theme and aesthetics
  xlab("Prompt-Model Index (Sorted)") +
  ylab("Coefficients") +
  facet_grid(V ~ Y, labeller=label_wrap_gen(width=30), scales="free_y") +
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
  group_by(V, coef_name) %>%
  arrange(V, coef_name, t) %>% 
  mutate(prompt.sorted = row_number()) %>% 
  ungroup() %>%
  mutate(prompt.sorted = as.factor(prompt.sorted))

# plot
fig02 <- data_fig02 %>%
  ggplot(aes(x=prompt.sorted, color=model, shape=model)) +
  geom_point(aes(y=t), size=1.25, alpha=0.7) +
  
  # theme and aesthetics
  xlab("Prompt-Model Index (Sorted)") +
  ylab("t-scores") +
  facet_grid(V ~ Y, labeller=label_wrap_gen(width=30), scales="free_y") +
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
facet.labeller <- labeller(
  Y = function(Y) Y,
  proportion = function(proportion) sprintf("Validation Proportion=%s%%", as.numeric(proportion)*100)
)

fig03 <- data_5k %>%
  filter(
    proportion==0.05, 
    regression=="LLM"
  ) %>%
  ggplot(aes(x=bias_mean, y=after_stat(count/tapply(count, PANEL, FUN=sum)[PANEL]), fill=regression)) +
  geom_vline(xintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  geom_histogram(bins=n_bins, color="white") +  
  geom_hline(yintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  
  # theme and aesthetics
  xlab("Bias") +
  ylab("Probability Densities") +
  facet_grid( ~ Y, labeller=label_wrap_gen(width=22)) +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0, 1, by=0.01), limits=c(0,0.25)) +
  theme.bar + 
  guides(fill="none")

# save figure
fig_path = file.path(fig_dir, "fig03 Bias Density LLM.jpeg")
ggsave(fig_path, plot = fig03, height = 2.3, width = 9)
cat(sprintf("Saved %s\n", fig_path))


# Figure 4: Normalized Bias Density of the LLM Coefficent
fig04 <- data_5k %>%
  filter(
    proportion==0.05,
    regression=="LLM"
  ) %>%
  ggplot(aes(x=bias_norm, y=after_stat(count/tapply(count, PANEL, FUN=sum)[PANEL]), fill=regression)) +
  geom_vline(xintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  geom_histogram(bins=n_bins, color="white") +
  geom_hline(yintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  
  # theme and aesthetics
  xlab("Normalized Bias") +
  ylab("Probability Densities") + 
  facet_grid( ~ Y, labeller=label_wrap_gen(width=22)) +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1,by=0.01), limits=c(0,0.25)) +
  theme.bar + 
  guides(fill="none")

# save figure
fig_path = file.path(fig_dir, "fig04 Normalized Bias Density LLM.jpeg")
ggsave(fig_path, plot = fig04, height = 2.3, width = 9)
cat(sprintf("Saved %s\n", fig_path))


# Figure 5: Bias Density by Model and Validation Proportion
n_bins <- 50
# proportion_levels <- c(0.05, 0.1, 0.5)
# proportion_labels <- sprintf("Val. Prop. %s%%", as.numeric(proportion_levels)*100)

proportion_labeller <- labeller(
  proportion = function(proportion) sprintf("Validation Prop. = %s%%", as.numeric(proportion)*100),
  .default=label_wrap_gen(25)
)

fig05 <- list()
for (Yi_label in unique(data_5k$Y)){
  Yi_level = Y_levels[Yi_label]
  
  fig05_Y <- data_5k %>%
    filter(
      # proportion != 0.25,
      regression != "Human Validation",
      Y == Yi_label
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
    facet_grid(model ~ proportion, labeller=proportion_labeller, scales = "free_x") +
    scale_fill_manual(name=NULL, values=my_colors) +
    scale_x_symmetric(mid=0) +
    scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
    theme.bar
  
  fig05[[Yi_level]] <- fig05_Y
  
  # save figure
  fig_path = file.path(fig_dir, sprintf("fig05_%s Bias Density by Model and Validation Proportion.jpeg", Yi_level))
  ggsave(fig_path, plot = fig05_Y, height = 4.5, width = 9)
  cat(sprintf("Saved %s\n", fig_path))
}

# Figure 6: Normalized Bias Density by Model and Validation Proportion
fig06 <- list()
for (Yi_label in unique(data_5k$Y)){
  Yi_level = Y_levels[Yi_label]
  
  fig06_Y <- data_5k %>%
    filter(
      # proportion != 0.25,
      regression != "Human Validation",
      Y == Yi_label
    ) %>%
    ggplot(aes(x=bias_norm, y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]),
               group=regression, fill=regression)) +
    geom_histogram(bins=n_bins, position=position_dodge()) +
    
    # theme and aesthetics
    xlab("Normalized Bias") +
    ylab("Probability Densities") +
    facet_grid(model ~ proportion, labeller=proportion_labeller) +
    scale_fill_manual(name=NULL, values=my_colors) +
    scale_x_symmetric(mid=0) +
    scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
    theme.bar
  
  fig06[[Yi_level]] <- fig06_Y
  
  # save figure
  fig_path = file.path(fig_dir, sprintf("fig06_%s Normalized Bias Density by Model and Validation Proportion.jpeg", Yi_level))
  ggsave(fig_path, plot = fig06_Y, height = 4.5, width = 9)
  cat(sprintf("Saved %s\n", fig_path))
}

# Figure 7: MSE CDF by Validation Proportion
fig07 <- data_5k %>%
  filter(
    # proportion != 0.25,
    regression != "LLM"
  ) %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("log(MSE)") +
  ylab("Empirical CDF") +
  facet_grid(Y ~ proportion, labeller=proportion_labeller) +
  # coord_cartesian(xlim=c(0,0.03)) +
  scale_x_log10(
    minor_breaks = c(
      seq(0.0002, 0.001, by = 0.0001),
      seq(0.002, 0.01, by = 0.001),
      seq(0.02, 0.1, by = 0.01),
      seq(0.1, 1, by = 0.1),
      seq(2, 10, by = 1),
      seq(20, 100, by = 10),
      seq(200, 1000, by = 100)
    ),
    breaks = c(0.001, 0.01, 0.1, 1, 10, 100),
    labels=c(TeX("$10^{-3}$"), TeX("$10^{-2}$"), TeX("$10^{-1}$"), TeX("$10^{0}$"), TeX("$10^{1}$"), TeX("$10^{2}$"))
  ) +
  scale_color_manual(name="", values=my_colors) +
  scale_linetype_manual(name="", values=c("dashed", "solid")) +
  theme.mse
  
# save figure
fig_path = file.path(fig_dir, "fig07 MSE CDF by Validation Proportion.jpeg")
ggsave(fig_path, plot = fig07, height = 9, width = 9)
cat(sprintf("Saved %s\n", fig_path))


# Figure 8: MSE CDF by Model and Validation Proportion
fig08 <- list()
for (Yi_label in unique(data_5k$Y)){
  Yi_level = Y_levels[Yi_label]
  fig08_Y <- data_5k %>%
    filter(
      # proportion != 0.25,
      regression != "LLM",
      Y == Yi_label
    ) %>%
    ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
    stat_ecdf(linewidth=0.5) +
    
    # theme and aesthetics
    xlab("log(MSE)") +
    ylab("Empirical CDF") +
    facet_grid(model ~ proportion, labeller=proportion_labeller) +
    scale_x_log10(
      minor_breaks = c(
        seq(0.0002, 0.001, by = 0.0001), 
        seq(0.002, 0.01, by = 0.001), 
        seq(0.02, 0.1, by = 0.01), 
        seq(0.1, 1, by = 0.1), 
        seq(2, 10, by = 1), 
        seq(20, 100, by = 10),
        seq(200, 1000, by = 100)
      ),
      breaks = c(0.001, 0.01, 0.1, 1, 10, 100), 
      labels=c(TeX("$10^{-3}$"), TeX("$10^{-2}$"), TeX("$10^{-1}$"), TeX("$10^{0}$"), TeX("$10^{1}$"), TeX("$10^{2}$"))
    ) +
    scale_color_manual(name="", values=my_colors) +
    scale_linetype_manual(name="", values=c("dashed", "solid")) +
    theme.mse
  
  fig08[[Yi_level]] <- fig08_Y
  
  # save figure
  fig_path = file.path(fig_dir, sprintf("fig08_%s MSE CDF by Model and Validation Proportion.jpeg", Yi_level))
  ggsave(fig_path, plot = fig08_Y, height = 4.5, width = 9)
  cat(sprintf("Saved %s\n", fig_path))
}

