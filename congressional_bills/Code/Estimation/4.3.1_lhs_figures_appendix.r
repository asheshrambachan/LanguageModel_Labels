# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/LHS")
fig_dir <- file.path(repo_dir, "Figures/Appendix/Estimation/LHS")

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
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13", "Validation")
model_labels <- c("GPT-3.5", "GPT-4o", "Validation")
Y_levels <- c(3, 14, 15, 19, 20)
Y_labels <- c( "Health", "Banking, Finance, and Domestic Commerce", "Defense", "Government Operations", "Public Lands and Water Management")
regression_levels <- c("5k_Yllm_V", "train_Yhuman_V", "Ytilde_V")
regression_labels <- c("LLM", "Validation", "Debiased")
proportion_labeller <- labeller(
  proportion = function(proportion) sprintf("Validation Proportion = %s%%", as.numeric(proportion)*100)
)


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
    model = factor("Validation", levels=model_levels, labels=model_labels),
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

n_bins <- 64

# Figure 3: Bias Density by Model, LLM Only
# fig03 <- data_5k %>%
#   filter(
#     proportion==0.10, 
#     regression=="LLM"
#   ) %>%
#   ggplot(aes(
#     x=bias_mean, 
#     y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]), 
#     fill=regression,
#     color=regression
#   )) +
#   geom_vline(xintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
#   geom_histogram(bins=n_bins, position="identity") +  
#   
#   # theme and aesthetics
#   xlab("Bias") +
#   ylab("Probability Densities") +
#   facet_grid( ~ model) +
#   scale_fill_manual(name=NULL, values=alpha(my_colors, 0.3)) +
#   scale_color_manual(name=NULL, values=my_colors) +
#   scale_x_symmetric(mid=0) +
#   scale_y_continuous(minor_breaks=seq(0, 1, by=0.01), limits=c(0,0.25)) +
#   theme.bar + 
#   guides(fill="none", color="none")
# 
# # save figure
# fig_path = file.path(fig_dir, "fig03 Bias Density by Model, Val Prop 10, LLM Only.jpeg")
# ggsave(fig_path, plot = fig03, height = 3.75, width = 8)
# cat(sprintf("Saved %s\n", fig_path))


# # Figure 4: Normalized Bias Density by Model, LLM Only
# fig04 <- data_5k %>%
#   filter(
#     proportion==0.10,
#     regression=="LLM"
#   ) %>%
#   ggplot(aes(
#     x=bias_norm,
#     y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]),
#     fill=regression,
#     color=regression
#   )) +
#   geom_vline(xintercept=0, color=my_palette[["lightgray"]], linewidth=0.3) +
#   geom_histogram(bins=n_bins, position="identity") +
# 
#   # theme and aesthetics
#   xlab("Normalized Bias") +
#   ylab("Probability Densities") +
#   facet_grid( ~ model) +
#   scale_fill_manual(name=NULL, values=alpha(my_colors, 0.3)) +
#   scale_color_manual(name=NULL, values=my_colors) +
#   scale_x_symmetric(mid=0) +
#   scale_y_continuous(minor_breaks=seq(0,1,by=0.01), limits=c(0,0.25)) +
#   theme.bar +
#   guides(fill="none", color="none")
# 
# # save figure
# fig_path = file.path(fig_dir, "Normalized Bias Density by Model, Val Prop 10, LLM Only.jpeg")
# ggsave(fig_path, plot = fig04, height = 3.75, width = 8)
# cat(sprintf("Saved %s\n", fig_path))

# Figure 5: Bias Density by Model and Validation Proportion
fig05 <- data_5k %>%
  filter(regression!="Validation") %>%
  ggplot(aes(
    x=bias_mean, 
    y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]), 
    color=regression, 
    fill=regression
  )) +
  geom_histogram(bins=n_bins, position="identity") +
  
  # theme and aesthetics
  xlab("Bias") +
  ylab("Probability Densities") +
  facet_grid(model ~ proportion, labeller=proportion_labeller) +
  scale_fill_manual(name=NULL, values=alpha(my_colors, 0.3)) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar

# save figure
fig_path = file.path(fig_dir, "Bias Density by Model and Validation Proportion.jpeg")
ggsave(fig_path, plot = fig05, height = 4, width = 9)
cat(sprintf("Saved %s\n", fig_path))


# Figure 6: Normalized Bias Density by Model and Validation Proportion
fig06 <- data_5k %>%
  filter(regression!="Validation") %>%
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
  facet_grid(model ~ proportion, labeller=proportion_labeller) +
  scale_fill_manual(name=NULL, values=alpha(my_colors, 0.3)) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  theme.bar

# save figure
fig_path = file.path(fig_dir, "Normalized Bias Density by Model and Validation Proportion.jpeg")
ggsave(fig_path, plot = fig06, height = 4, width = 9)
cat(sprintf("Saved %s\n", fig_path))

# Figure 7: MSE CDF by Validation Proportion
fig07 <- data_5k %>%
  filter(regression != "LLM") %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  facet_grid(. ~ proportion, labeller=proportion_labeller) +
  scale_x_continuous(minor_breaks = seq(0,1,0.0001)) +
  coord_cartesian(xlim=c(0,0.002)) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_linetype_manual(name=NULL, values=c("dashed", "solid")) +
  theme.mse

# save figure
fig_path = file.path(fig_dir, "MSE CDF by Validation Proportion.jpeg")
ggsave(fig_path, plot = fig07, height = 3, width = 9)
cat(sprintf("Saved %s\n", fig_path))


# Figure 8: MSE CDF by Model and Validation Proportion
fig08 <- data_5k %>%
  filter(
    # proportion != 0.25,
    regression != "LLM"
  ) %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  facet_grid(model ~ proportion, labeller=proportion_labeller) +
  scale_x_continuous(minor_breaks = seq(0,1,0.0001)) +
  coord_cartesian(xlim=c(0,0.002)) +
  scale_color_manual(name=NULL, values=my_colors) +
  scale_linetype_manual(name=NULL, values=c("dashed", "solid")) +
  theme.mse

# save figure
fig_path = file.path(fig_dir, "MSE CDF by Model and Validation Proportion.jpeg")
ggsave(fig_path, plot = fig08, height = 4.5, width = 9)
cat(sprintf("Saved %s\n", fig_path))
