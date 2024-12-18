# Aug 12, 2024

# Removing all objects
rm(list = ls())

# Load packages
suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(latex2exp)
  library(logger)
})

# Setup directories
repo_dir <- "."
data_dir <- file.path(repo_dir, "estimation_cb/data")
lhs_dir <- file.path(repo_dir, "estimation_cb/temp/LHS")
dir.create(data_dir, showWarnings=FALSE, recursive = TRUE)

# Data paths
rds_paths <- list.files(lhs_dir, pattern="*.rds", full.names=TRUE)
data_bills_path <- file.path(data_dir, "bills.csv")
plugin_data_path <- file.path(data_dir, "lhs_10k_plugin.csv")
validation_data_path <- file.path(data_dir, "lhs_10k_validation.csv")
plugin_validation_debiased_averaged_data_path <- file.path(data_dir, "lhs_5k_plugin_validation_debiased_averaged.csv")
summary_stat_10k_path <- file.path(data_dir, "lhs_10k_plugin_summary_stat.csv")
summary_stat_5k_path <- file.path(data_dir, "lhs_5k_plugin_validation_debiased_averaged_summary_stat.csv")

# Functions 
bias = function(coef, coef.ref) return(coef - coef.ref) # Calculate bias
mse = function(coef, coef.ref) return((coef - coef.ref)^2)  # Calculate Mean Squared Error (MSE)
coverage = function(coef.ref, lci, uci) return(as.integer((lci <= coef.ref) & (coef.ref <= uci))) # Check if the confidence interval covers the reference coefficient

# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)

# Factor labels and levels
V_labels_levels <- c(
  `3` ="Health", 
  `14`="Banking, Finance & Domestic Commerce", 
  `15`="Defense", 
  `19`="Government Operations", 
  `20`="Public Lands & Water Management"
)
regression_labels_levels <- c(
  "10k_Yllm_V"="10k Plug-In", 
  "10k_Yhuman_V"="10k Validation",
  "5k_Yllm_V"="Plug-In", 
  "train_Yhuman_V"="Validation", 
  "Ytilde_V"="Debiased"
)

# Read all RDS files and combine them into a single data frame
data <- bind_rows(lapply(rds_paths, readRDS)) %>% 
  filter(
    regression %in% names(regression_labels_levels),
    coef_name!="(Intercept)"
  ) %>%
  select(!c(class, coef_name)) %>%
  rename(c(
    V=major_topic, 
    W=variable,
    proportion=train_proportion
  )) %>%
  mutate(
    regression=recode_factor(regression, !!!regression_labels_levels),
    V=recode_factor(V, !!!V_labels_levels),
    ) %>%
  mutate(across(where(is.numeric), ~ round(.x, digits = 11))) # Round to 11 decimals

log_info("Loaded *.rds files at {lhs_dir}")

# Save lhs_10k_plugin.csv
plugin_data <- data %>% 
  filter(regression=="10k Plug-In") %>%
  select(c(prompt, model, W, V, coef, t, lci, uci)) %>%
  distinct()
write.csv(plugin_data, plugin_data_path, row.names=FALSE)
log_info("Saved {plugin_data_path}")

# Summary stat: point estimate 
plugin_summary_stat_data <- plugin_data %>%
  tidyr::pivot_longer(
    cols = c(coef),
    names_to = "statistic_name",
    values_to = "statistic"
  ) %>%
  group_by(W, V, statistic_name) %>%
  summarise(
    "Mean" = mean(statistic),
    "Median" = median(statistic),
    "SD" = sd(statistic),
    "CI05" = quantile(statistic, probs[1]),
    "CI95" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

# Load bills data to get sample averages
coef_sample_average_data <- read.csv(data_bills_path) %>%
  rename(V=Major) %>%
  filter(V %in% names(V_labels_levels)) %>%
  mutate(V=recode_factor(V, !!!V_labels_levels)) %>%
  group_by(V) %>%
  summarise(count = n()) %>%
  mutate("Sample Average" = count / sum(count)) %>%
  select(!count)

# Merge and save summary_stat_10k
summary_stat_10k <- merge(plugin_summary_stat_data, coef_sample_average_data, by="V") %>%
  arrange(V, W)
write.csv(summary_stat_10k, summary_stat_10k_path, row.names=FALSE)
log_info("Saved {summary_stat_10k_path}")

# Save lhs_10k_validation.csv
validation_data <- data %>% 
  filter(regression=="10k Validation") %>%
  select(W, V, coef, t, lci, uci) %>%
  distinct()
write.csv(validation_data, validation_data_path, row.names=FALSE)
log_info("Saved {validation_data_path}")

# Filter out the remaining regressions of interest. Compute the bias/mse/coverage relative to the reference regression
plugin_validation_debiased_data <- data %>% 
  filter(regression %in% regression_labels_levels[3:5]) %>%
  merge(x=., y=validation_data, by=c("W", "V"), suffixes=c("",".ref")) %>%
  mutate(
    bias = bias(coef, coef.ref), # Calculate bias
    mse = mse(coef, coef.ref),  # Calculate Mean Squared Error (MSE)
    coverage = coverage(coef.ref, lci, uci),  # Check if the confidence interval covers the reference coefficient
  ) %>%
  select(!contains(".ref")) 

# Calculate the average of bias, MSE, and coverage for each combination, and save the averaged results to a new CSV file
plugin_validation_debiased_averaged_data <- plugin_validation_debiased_data %>%
  group_by(combination_id, proportion, model, prompt, W, V, regression) %>% 
  summarise(
    coef_mean = mean(coef),
    coef_sd = sd(coef), 
    bias_mean = mean(bias), 
    bias_norm = bias_mean/coef_sd,
    mse_mean = mean(mse), 
    coverage_mean = mean(coverage), 
    .groups = "drop"
  ) 
write.csv(plugin_validation_debiased_averaged_data, plugin_validation_debiased_averaged_data_path, row.names=FALSE)
log_info("Saved {plugin_validation_debiased_averaged_data_path}")

# Summary stat: bias_mean, bias_norm, mse_mean, coverage_mean
summary_stat_5k <- plugin_validation_debiased_averaged_data %>%
  select(c(model, regression, proportion, bias_mean, bias_norm, mse_mean, coverage_mean)) %>%
  tidyr::pivot_longer(
    cols = c(bias_mean, bias_norm, mse_mean, coverage_mean),
    names_to = "statistic_name",
    values_to = "statistic"
  ) %>%
  group_by(model, regression, proportion, statistic_name) %>%
  summarise(
    "Mean" = mean(statistic),
    "Median" = median(statistic),
    "SD" = sd(statistic),
    "CI05" = quantile(statistic, probs[1]),
    "CI95" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) %>%
  arrange(model, regression, statistic_name, proportion)
write.csv(summary_stat_5k, summary_stat_5k_path, row.names=FALSE)
log_info("Saved {summary_stat_5k_path}")
