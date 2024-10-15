# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/LHS")
fig_dir <- file.path(repo_dir, "Figures/Slides/Estimation/LHS")
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

# Load averaged simulation data
data_5k <- read.csv(path_data_5k) %>%
  mutate(
    bias_norm = bias_mean/coef_sd, 
    V = factor(V, levels=V_levels),
    model = factor(model, levels=model_levels, labels=model_labels),
    regression = factor(regression, levels=regression_levels, labels=regression_labels)
  ) %>%
  rename(proportion=train_proportion) %>%
  filter(
    coef_name!="(Intercept)",
    proportion==0.10
    ) %>%
  select(model, regression, bias_norm, mse_mean, coverage_mean)

n_bins <- 40
binwidth <- 0.09

# Figure: Normalized Bias Density of the LLM Coefficent, Validation 10%
fig_data <- data_5k %>%
  filter(regression=="LLM")
fig_color <- my_colors[as.character(sort(unique(fig_data$regression)))]

norm_bias1 <- fig_data %>%
  ggplot(aes(x=bias_norm, y=after_stat(count/sum(count)), fill=regression, color=regression)) +
  geom_histogram(binwidth=binwidth, position = "identity") +
  
  # theme and aesthetics
  xlab("Normalized Bias") +
  ylab("Probability Densities") + 
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0,1,by=0.01), limits=c(0,0.25)) +
  theme.bar + 
  guides(color="none", fill="none")

norm_bias1_frame1 <- norm_bias1 +
  scale_fill_manual(name=NULL, values=alpha(fig_color, 0)) +
  scale_color_manual(name=NULL, values=alpha(fig_color, 0))
  
norm_bias1_frame2 <- norm_bias1 +
  scale_fill_manual(name=NULL, values=alpha(fig_color, 0.3)) +
  scale_color_manual(name=NULL, values=alpha(fig_color, 1))

# save figure
ggsave(file.path(fig_dir, "Normalized Bias Density LLM, Val 0.1 (frame1).jpeg"), plot = norm_bias1_frame1, height = 4, width = 5)
ggsave(file.path(fig_dir, "Normalized Bias Density LLM, Val 0.1 (frame2).jpeg"), plot = norm_bias1_frame2, height = 4, width = 5)


# Figure: Normalized Bias Density by Model, Validation 10%
fig_data <- data_5k %>%
  filter(regression!="Human Validation")
fig_color <- my_colors[as.character(sort(unique(fig_data$regression)))]

norm_bias2 <- fig_data %>%
  ggplot(aes(
    x=bias_norm,  
    y=after_stat(max(group)*count/tapply(count, PANEL, FUN=sum)[PANEL]),
    group=regression, fill=regression, color=regression
  )) +
  geom_histogram(binwidth=binwidth, position = "identity") +
  
  # theme and aesthetics
  xlab("Normalized Bias") +
  ylab("Probability Densities") +
  facet_grid( ~ model) +
  scale_x_symmetric(mid=0) +
  scale_y_continuous(minor_breaks=seq(0, 1, by=0.05), limits=c(0,1)) +
  theme.bar

norm_bias2_frame1 <- norm_bias2 + 
  scale_fill_manual(name=NULL, values=alpha(fig_color, 0)) +
  scale_color_manual(name=NULL, values=alpha(fig_color, 0)) + 
  guides(color = guide_legend(override.aes = list(alpha=0.3, color=fig_color)))

norm_bias2_frame2 <- norm_bias2 +
  scale_fill_manual(name=NULL, values=alpha(fig_color, c(0.3,0))) +
  scale_color_manual(name=NULL, values=alpha(fig_color, c(1,0))) + 
  guides(color = guide_legend(override.aes = list(alpha=0.3, color=fig_color)))

norm_bias2_frame3 <- norm_bias2 +
  scale_fill_manual(name=NULL, values=alpha(fig_color, 0.3)) +
  scale_color_manual(name=NULL, values=alpha(fig_color, 1)) 

# save figure
ggsave(file.path(fig_dir, "Normalized Bias Density by Model, Val 0.1 (frame1).jpeg"), plot = norm_bias2_frame1, height = 4, width = 8)
ggsave(file.path(fig_dir, "Normalized Bias Density by Model, Val 0.1 (frame2).jpeg"), plot = norm_bias2_frame2, height = 4, width = 8)
ggsave(file.path(fig_dir, "Normalized Bias Density by Model, Val 0.1 (frame3).jpeg"), plot = norm_bias2_frame3, height = 4, width = 8)


# Figure: MSE CDF, Validation 10%
fig_data <- data_5k %>%
  filter(regression!="LLM")

fig_color <- my_colors[as.character(sort(unique(fig_data$regression)))]

mse1 <- fig_data %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  scale_x_continuous(minor_breaks = seq(0,1,0.0001)) +
  theme.mse + 
  scale_linetype_manual(name="", values=c("dashed", "solid")) 

mse1_frame1 <- mse1 +
  scale_color_manual(name="", values=alpha(fig_color, 0)) +
  guides(color = guide_legend(override.aes = list(alpha=1)))

mse1_frame2 <- mse1 +
  scale_color_manual(name="", values=alpha(fig_color, c(1,0))) +
  guides(color = guide_legend(override.aes = list(alpha=1)))

mse1_frame3 <- mse1 +
  scale_color_manual(name="", values=alpha(fig_color, 1))

# save figure
ggsave(file.path(fig_dir, "MSE CDF, Val 0.1 (frame1).jpeg"), plot = mse1_frame1, height = 4, width = 5)
ggsave(file.path(fig_dir, "MSE CDF, Val 0.1 (frame2).jpeg"), plot = mse1_frame2, height = 4, width = 5)
ggsave(file.path(fig_dir, "MSE CDF, Val 0.1 (frame3).jpeg"), plot = mse1_frame3, height = 4, width = 5)


# Figure: MSE CDF by Model, Validation 10%
mse2 <- fig_data %>%
  ggplot(aes(x=mse_mean, color=regression, linetype=regression)) +
  stat_ecdf(linewidth=0.5) +
  
  # theme and aesthetics
  xlab("MSE") +
  ylab("Empirical CDF") +
  facet_grid( ~ model, labeller=proportion_labeller) +
  theme.mse +
  scale_linetype_manual(name="", values=c("dashed", "solid"))

mse2_frame1 <- mse2 +
  scale_color_manual(name="", values=alpha(fig_color, 0)) +
  guides(color = guide_legend(override.aes = list(alpha=1)))

mse2_frame2 <- mse2 +
  scale_color_manual(name="", values=alpha(fig_color, c(1,0))) +
  guides(color = guide_legend(override.aes = list(alpha=1)))

mse2_frame3 <- mse2 +
  scale_color_manual(name="", values=alpha(fig_color, 1))

# save figure
ggsave(file.path(fig_dir, "MSE CDF by Model, Val 0.1 (frame1).jpeg"), plot = mse2_frame1, height = 4.5, width = 9)
ggsave(file.path(fig_dir, "MSE CDF by Model, Val 0.1 (frame2).jpeg"), plot = mse2_frame2, height = 4.5, width = 9)
ggsave(file.path(fig_dir, "MSE CDF by Model, Val 0.1 (frame3).jpeg"), plot = mse2_frame3, height = 4.5, width = 9)
