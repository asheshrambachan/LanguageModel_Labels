# Aug 12, 2024

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(latex2exp)
  library(logger)
})

# Define and set the working directory
# setwd("~/Documents/LanguageModel_Labels/congressional_bills/")
repo_dir <- "."
data_dir <- file.path(repo_dir, "Data")
temp_dir <- file.path(repo_dir, "Temp")
rhs_dir <- file.path(temp_dir, "rhs")

# Functions 
bias = function(coef, coef.ref) return(coef - coef.ref) # Calculate bias
mse = function(coef, coef.ref) return((coef - coef.ref)^2)  # Calculate Mean Squared Error (MSE)
coverage = function(coef.ref, lci, uci) return(as.integer((lci <= coef.ref) & (coef.ref <= uci))) # Check if the confidence interval covers the reference coefficient

# Proxy on the RHS
# Read all RDS files and combine them into a single data frame
rds_paths <- list.files(rhs_dir, pattern="*.rds", full.names=TRUE)

data <- bind_rows(lapply(rds_paths, readRDS)) %>% 
  rename(c(V=variable))
log_info("Loaded *.rds files at {rhs_dir}")

regressions_of_intreset <- c("10k_V_Yhuman", "10k_V_Yllm", "5k_V_Yllm", "train_V_Yhuman", "Vtilde_Ytilde")
data %>% 
  filter(!(regression %in% regressions_of_intreset)) %>%
  write.csv(file.path(temp_dir, "rhs_other.csv"), row.names=FALSE)
log_info("Saved rhs_other.csv at {temp_dir}")

data <- data %>% filter(regression %in% regressions_of_intreset)

# Save the 10k_V_Yllm results in a separate file
data %>% 
  filter(regression=="10k_V_Yllm") %>%
  select(c("prompt", "model", "V", "regression", "coef_name", "coef", "se", "t", "lci", "uci")) %>%
  distinct() %>%
  write.csv(file.path(data_dir, "rhs_10k_llm.csv"), row.names=FALSE)
log_info("Saved rhs_10k_llm.csv at {data_dir}")

# Extract reference regression results (10k_V_Yhuman)
regression.ref <- data %>% 
  filter(regression=="10k_V_Yhuman") %>%
  select(regression, V, coef_name, coef, se, t, lci, uci) %>%
  distinct()
write.csv(regression.ref, file.path(data_dir, "rhs_10k_human.csv"), row.names=FALSE)
log_info("Saved rhs_10k_human.csv at {data_dir}")

# Filter out the remaining regressions of interest. Compute the bias/mse/coverage relative to the reference regression
regressions <- data %>% 
  filter(regression %in% c("5k_V_Yllm", "train_V_Yhuman", "Vtilde_Ytilde")) %>%
  merge(x=., y=regression.ref, by=c("V", "coef_name"), suffixes=c("",".ref")) %>%
  mutate(
    bias = bias(coef, coef.ref), # Calculate bias
    mse = mse(coef, coef.ref),  # Calculate Mean Squared Error (MSE)
    coverage = coverage(coef.ref, lci, uci),  # Check if the confidence interval covers the reference coefficient
  ) %>%
  arrange(combination_id, sim_number, coef_name) %>%
  relocate(coef_name, .before=coef) %>%
  relocate(sim_number, .before=regression) 
write.csv(data, file.path(temp_dir, "rhs_5k_llm_human_debiased.csv"), row.names=FALSE)
log_info("Saved rhs_5k_llm_human_debiased_averaged.csv at {data_dir}")

# For all other regressions, calculate the average of bias, MSE, and coverage for each combination, and save the averaged results to a new CSV file
regressions %>% 
  group_by(combination_id, train_proportion, model, prompt, V, regression, coef_name) %>% 
  summarise(
    coef_mean = mean(coef),
    coef_sd = sd(coef), 
    bias_mean = mean(bias), 
    bias_norm = bias_mean/coef_sd,
    mse_mean = mean(mse), 
    coverage_mean = mean(coverage), 
    .groups = "drop") %>%
  select(!contains(".ref")) %>%
  write.csv(file.path(data_dir, "rhs_5k_llm_human_debiased_averaged.csv"), row.names=FALSE)
log_info("Saved rhs_5k_llm_human_debiased_averaged.csv at {data_dir}")


