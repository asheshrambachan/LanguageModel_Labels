# Aug 12, 2024

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(latex2exp)
  library(logger)
})

# Define and set the working directory
setwd("~/Documents/LanguageModel_Labels/estimation_cb")
repo_dir <- "."
data_dir <- file.path(repo_dir, "Data")
temp_dir <- file.path(repo_dir, "Temp/LHS")
lhs_dir <- file.path(temp_dir, "rds")
dir.create(data_dir, showWarnings=FALSE, recursive = TRUE)

# Functions 
bias = function(coef, coef.ref) return(coef - coef.ref) # Calculate bias
mse = function(coef, coef.ref) return((coef - coef.ref)^2)  # Calculate Mean Squared Error (MSE)
coverage = function(coef.ref, lci, uci) return(as.integer((lci <= coef.ref) & (coef.ref <= uci))) # Check if the confidence interval covers the reference coefficient

# Proxy on the LHS
# Read all RDS files and combine them into a single data frame
rds_paths <- list.files(lhs_dir, pattern="*.rds", full.names=TRUE)

data <- bind_rows(lapply(rds_paths, readRDS)) %>% 
  rename(c(Y=major_topic, V=variable))
log_info("Loaded *.rds files at {lhs_dir}")

regressions_of_intreset <- c("10k_Yhuman_V", "10k_Yllm_V", "5k_Yllm_V", "train_Yhuman_V", "Ytilde_V")
data %>% 
  filter(!(regression %in% regressions_of_intreset)) %>%
  write.csv(file.path(temp_dir, "lhs_other.csv"), row.names=FALSE)
log_info("Saved lhs_other.csv at {temp_dir}")

data <- data %>% filter(regression %in% regressions_of_intreset)

# Save the 10k_Yllm_V results in a separate file. 
data_llm <- data %>% 
  filter(regression=="10k_Yllm_V") %>%
  select(c("prompt", "model", "V", "Y", "regression", "coef_name", "coef", "se", "t", "lci", "uci")) %>%
  distinct()
write.csv(data_llm, file.path(data_dir, "lhs_10k_llm.csv"), row.names=FALSE)
log_info("Saved lhs_10k_llm.csv at {data_dir}")

# Extract reference regression results (10k_Yhuman_V). 
regression.ref <- data %>% 
  filter(regression=="10k_Yhuman_V") %>%
  select(regression, V, Y, coef_name, coef, se, t, lci, uci) %>%
  distinct()
write.csv(regression.ref, file.path(data_dir, "lhs_10k_human.csv"), row.names=FALSE)
log_info("Saved lhs_10k_human.csv at {data_dir}")

# Filter out the remaining regressions of interest. Compute the bias/mse/coverage relative to the reference regression
regressions <- data %>% 
  filter(regression %in% c("5k_Yllm_V", "train_Yhuman_V", "Ytilde_V")) %>%
  merge(x=., y=regression.ref, by=c("V", "Y", "coef_name"), suffixes=c("",".ref")) %>%
  mutate(
    bias = bias(coef, coef.ref), # Calculate bias
    mse = mse(coef, coef.ref),  # Calculate Mean Squared Error (MSE)
    coverage = coverage(coef.ref, lci, uci),  # Check if the confidence interval covers the reference coefficient
  ) %>%
  arrange(combination_id, sim_number, coef_name) %>%
  relocate(coef_name, .before=coef) %>%
  relocate(sim_number, .before=regression) 
write.csv(regressions, file.path(temp_dir, "lhs_5k_llm_human_debiased.csv"), row.names=FALSE)
log_info("Saved lhs_5k_llm_human_debiased.csv at {temp_dir}")

# Calculate the average of bias, MSE, and coverage for each combination, and save the averaged results to a new CSV file
regressions %>% 
  group_by(combination_id, train_proportion, model, prompt, V, Y, regression, coef_name) %>% 
  summarise(
    coef_mean = mean(coef),
    coef_sd = sd(coef), 
    bias_mean = mean(bias), 
    bias_norm = bias_mean/coef_sd,
    mse_mean = mean(mse), 
    coverage_mean = mean(coverage), 
    .groups = "drop") %>%
  select(!contains(".ref")) %>%
  write.csv(file.path(data_dir, "lhs_5k_llm_human_debiased_averaged.csv"), row.names=FALSE)
log_info("Saved lhs_5k_llm_human_debiased_averaged.csv at {data_dir}")
