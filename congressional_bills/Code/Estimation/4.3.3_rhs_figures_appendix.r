# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/RHS")
fig_dir <- file.path(repo_dir, "Figures/Estimation/RHS")
slides_fig_dir <- file.path(repo_dir, "Figures/Figures_For_Slides/CongressionalBills_Estimation/LLM_On_RHS")

dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)
dir.create(slides_fig_dir, showWarnings=FALSE, recursive = TRUE)

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
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13", "Validation")
model_labels <- c("GPT-3.5", "GPT-4o", "Validation")
regression_levels <- c("5k_V_Yllm", "train_V_Yhuman", "Vtilde_Ytilde")
regression_labels <- c("LLM", "Validation", "Debiased")
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
  geom_point(aes(y=coef), size=1.25) +
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
fig_path = file.path(fig_dir, "fig01 Coefficient vs. Prompt-Model (Sorted).jpeg")
ggsave(fig_path, plot = fig01, height = 4, width = 9)
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
  geom_point(aes(y=t), size=1.25) +
  
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
ggsave(fig_path, plot = fig02, height = 4, width = 9)
cat(sprintf("Saved %s\n", fig_path))


# Figure 3: Bias Density by Model, Val Prop 10, LLM Only
n_bins <- 64

fig03 <- data_5k %>%
  filter(
    proportion==0.10, 
    regression=="LLM"
  ) %>%
  ggplot(aes(
    x=bias_mean, 
    y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]),
    fill=regression,
    color=regression
  )) +
  geom_vline(xintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  geom_histogram(bins=n_bins, position="identity", alpha=0.3) +  
  
  # theme and aesthetics
  xlab("Bias") +
  ylab("Probability Densities") +
  facet_grid( ~ model) +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0, 1, by=0.01), limits=c(0,0.25)) +
  theme.bar + 
  guides(fill="none", color="none")

# save figure
fig_path = file.path(fig_dir, "fig03 Bias Density by Model, Val Prop 10, LLM Only.jpeg")
ggsave(fig_path, plot = fig03, height = 3.75, width = 8)
cat(sprintf("Saved %s\n", fig_path))


# Figure 4: Normalized Bias Density by Model, Val Prop 10, LLM Only
fig04 <- data_5k %>%
  filter(
    proportion==0.10,
    regression=="LLM"
  ) %>%
  ggplot(aes(
    x=bias_norm, 
    y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]), 
    fill=regression,
    color=regression
  )) +
  geom_vline(xintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
  geom_histogram(bins=n_bins, position="identity") +  
  
  # theme and aesthetics
  xlab("Normalized Bias") +
  ylab("Probability Densities") + 
  facet_grid( ~ model) +
  scale_fill_manual(name=NULL, values=alpha(my_colors, 0.3)) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1,by=0.01), limits=c(0,0.25)) +
  theme.bar + 
  guides(fill="none", color="none")

# save figure
fig_path = file.path(fig_dir, "fig04 Normalized Bias Density by Model, Val Prop 10, LLM Only.jpeg")
ggsave(fig_path, plot = fig04, height = 3.75, width = 8)
cat(sprintf("Saved %s\n", fig_path))

# Create frames for the slides: Normalized Bias Density by Model, Val Prop 10%, LLM Only
fig04_frame1 <- fig04 +
  scale_fill_manual(name=NULL, values=alpha(my_colors, 0)) +
  scale_color_manual(name=NULL, values=alpha(my_colors, 0))
fig04_frame2 <- fig04

# save figure
ggsave(file.path(slides_fig_dir, "Normalized Bias Density by Model, Val Prop 10, LLM Only, Frame 1.jpeg"), plot = fig04_frame1, height = 3.75, width = 8)
ggsave(file.path(slides_fig_dir, "Normalized Bias Density by Model, Val Prop 10, LLM Only, Frame 2.jpeg"), plot = fig04_frame2, height = 3.75, width = 8)


# Figure 5: Bias Density by Model and Validation Proportion
fig05 <- data_5k %>%
  filter(regression != "Validation") %>%
  ggplot(aes(
    x=bias_mean, 
    y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]), 
    fill=regression,
    color=regression
  )) +
  geom_histogram(bins=n_bins, position="identity", alpha=0.3) +
  
  # theme and aesthetics
  xlab("Bias") +
  ylab("Probability Densities") +
  facet_grid(model ~ proportion, labeller=proportion_labeller, scales = "free_x") +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar

# save figure
fig_path = file.path(fig_dir, "fig05 Bias Density by Model and Validation Proportion, Pooled.jpeg")
ggsave(fig_path, plot = fig05, height = 4, width = 9)
cat(sprintf("Saved %s\n", fig_path))


# Figure 6: Normalized Bias Density by Model and Validation Proportion
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
  facet_grid(model ~ proportion, labeller=proportion_labeller) +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar

# save figure
fig_path = file.path(fig_dir, "fig06 Normalized Bias Density by Model and Validation Proportion, Pooled.jpeg")
ggsave(fig_path, plot = fig06, height = 4, width = 9)
cat(sprintf("Saved %s\n", fig_path))

# Create frames for the slides: Normalized Bias Density by Model, Val Prop 10%
fig06_prop10_frame2 <- data_5k %>%
  filter(
    regression!="Validation",
    proportion==0.1
  ) %>%
  ggplot(aes(
    x=bias_norm, 
    y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]),
    color=regression, 
    fill=regression
  )) +
  geom_histogram(bins=n_bins, position="identity") +
  
  # theme and aesthetics
  xlab("Normalized Bias") +
  ylab("Probability Densities") +
  facet_grid( ~ model) +
  scale_fill_manual(name=NULL, values=alpha(my_colors, 0.3)) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar

fig_color <- my_colors[as.character(sort(unique(fig06_prop10_frame2$data$regression)))]
fig06_prop10_frame1 <- fig06_prop10_frame2 + 
  scale_fill_manual(name=NULL, values=alpha(my_colors, 0)) +
  scale_color_manual(name=NULL, values=alpha(my_colors, 0)) + 
  guides(color = guide_legend(override.aes = list(alpha=0.3, color=fig_color)))

# save figure
ggsave(file.path(slides_fig_dir, "Normalized Bias Density by Model, Val Prop 10, LLM and Debiased, Pooled, Frame 1.jpeg"), plot = fig06_prop10_frame1, height = 4, width = 8)
ggsave(file.path(slides_fig_dir, "Normalized Bias Density by Model, Val Prop 10, LLM and Debiased, Pooled, Frame 2.jpeg"), plot = fig06_prop10_frame2, height = 4, width = 8)


# Figure 7: MSE CDF by Validation Proportion
fig07 <- data_5k %>%
  filter(regression != "LLM") %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  facet_grid(~ proportion, labeller=proportion_labeller) +
  scale_x_continuous(minor_breaks = seq(0,1,0.002)) +
  coord_cartesian(xlim=c(0,0.04)) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_linetype_manual(name=NULL, values=c("dashed", "solid")) +
  theme.mse

# save figure
fig_path = file.path(fig_dir, "fig07 MSE CDF by Validation Proportion, Pooled.jpeg")
ggsave(fig_path, plot = fig07, height = 3, width = 9)
cat(sprintf("Saved %s\n", fig_path))

# Create frames for the slides: MSE CDF, Validation 10%
fig07_prop10_frame2 <- data_5k %>%
  filter(
    regression!="LLM",
    proportion==0.1
  ) %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  theme.mse + 
  scale_linetype_manual(name=NULL, values=c("dashed", "solid"))  +
  scale_x_continuous(minor_breaks = seq(0,1,0.002)) +
  coord_cartesian(xlim=c(0,0.04)) +
  scale_color_manual(name=NULL, values=my_colors)

fig07_prop10_frame1 <- fig07_prop10_frame2 +
  scale_color_manual(name=NULL, values=alpha(my_colors, 0)) +
  guides(color = guide_legend(override.aes = list(alpha=1)))

# save figure
ggsave(file.path(slides_fig_dir, "MSE CDF, Val Prop 10, Frame 1.jpeg"), plot = fig07_prop10_frame1, height = 4, width = 5)
ggsave(file.path(slides_fig_dir, "MSE CDF, Val Prop 10, Frame 2.jpeg"), plot = fig07_prop10_frame2, height = 4, width = 5)



# Figure 8: MSE CDF by Model and Validation Proportion
fig08 <- data_5k %>%
  filter(regression != "LLM") %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  facet_grid(model ~ proportion, labeller=proportion_labeller) +
  scale_x_continuous(minor_breaks = seq(0,1,0.002)) +
  coord_cartesian(xlim=c(0,0.04)) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_linetype_manual(name=NULL, values=c("dashed", "solid")) +
  theme.mse

# save figure
fig_path = file.path(fig_dir, "fig08 MSE CDF by Model and Validation Proportion, Pooled.jpeg")
ggsave(fig_path, plot = fig08, height = 4.5, width = 9)
cat(sprintf("Saved %s\n", fig_path))


# Create frames for the slides: MSE CDF by Model, Validation 10%
fig08_prop10_frame2 <- data_5k %>%
  filter(
    regression!="LLM",
    proportion==0.1
  ) %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  facet_grid( ~ model, labeller=proportion_labeller) +
  theme.mse +
  scale_linetype_manual(name=NULL, values=c("dashed", "solid")) +
  scale_x_continuous(minor_breaks = seq(0,1,0.002)) +
  coord_cartesian(xlim=c(0,0.04)) +
  scale_color_manual(name=NULL, values=my_colors)

fig08_prop10_frame1 <- fig08_prop10_frame2 +
  scale_color_manual(name=NULL, values=alpha(my_colors, 0)) +
  guides(color = guide_legend(override.aes = list(alpha=1)))

# save figure
ggsave(file.path(slides_fig_dir, "MSE CDF by Model, Val Prop 10, Frame 1.jpeg"), plot = fig08_prop10_frame1, height = 4, width = 8)
ggsave(file.path(slides_fig_dir, "MSE CDF by Model, Val Prop 10, Frame 2.jpeg"), plot = fig08_prop10_frame2, height = 4, width = 8)
