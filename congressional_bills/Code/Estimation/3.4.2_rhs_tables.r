require(dplyr)
require(kableExtra)

# Directories 
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/RHS")
tables_dir <- file.path(repo_dir, "Tables/Estimation/RHS")
dir.create(tables_dir, showWarnings=FALSE, recursive = TRUE)
path_data_5k <- file.path(data_dir, "rhs_5k_llm_human_debiased_averaged.csv")

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
Y_levels <- c(3, 14, 15, 19, 20, "Other")
Y_labels <- c( "Health", "Banking, Finance, and Domestic Commerce", "Defense", "Government Operations", "Public Lands and Water Management", "Other")
names(Y_levels) <- Y_labels
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13")
model_labels <- c("GPT-3.5", "GPT-4o")
regression_levels <- c("5k_V_Yllm", "train_V_Yhuman", "Vtilde_Ytilde")
regression_labels <- c("LLM", "Human Validation", "Debiased")
proportion_levels <- c(0.05, 0.10, 0.25, 0.50)
proportion_labels <- sprintf("%s\\%%", proportion_levels*100)


# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)

# Load data
data_5k <- read.csv(path_data_5k) %>%
  rename(proportion=train_proportion)  %>%
  filter(coef_name != "Other") %>%
  mutate(
    bias_norm = bias_mean/coef_sd, 
    Y = factor(coef_name, levels=Y_levels, labels=Y_labels),
    V = factor(V, levels=V_levels),
    model = factor(model, levels=model_levels, labels=model_labels),
    regression = factor(regression, levels=regression_levels, labels=regression_labels),
    proportion = factor(proportion, levels=proportion_levels, labels=proportion_labels)
  ) %>%
  rename(c(
    "Validation Proportion" = proportion, 
    "Proxy" = regression,
    "Model" = model)
  )


# Table 1: Bias by Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=bias_mean) %>%
  group_by(Y, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab01 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
    
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rlrrrrr", 
      caption=sprintf("Bias Summary Statistics of $\\beta_{t}$, $t=$ %s, by Proportion of Validation Samples.
      Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab01[[Yi_level]] <- tab_i
  attr(tab01[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab01){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab01_%s Bias by Validation Proportion.tex", Yi_level))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}


# Table 2: Normalized Bias by Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=bias_norm) %>%
  group_by(Y, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab02 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rlrrrrr", 
      caption=sprintf("Normalized Bias Summary Statistics of $\\beta_{t}$, $t=$ %s, by Proportion of Validation Samples.
      Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab02[[Yi_level]] <- tab_i
  attr(tab02[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab02){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab02_%s Normalized Bias by Validation Proportion.tex", Yi_level))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}


# Table 3: Bias by Model and Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=bias_mean) %>%
  group_by(Y, Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab03 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rrlrrrrr", 
      caption=sprintf("Bias Summary Statistics of $\\beta_{t}$, $t=$ %s, by Model and Proportion of Validation Samples.
      Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab03[[Yi_level]] <- tab_i
  attr(tab03[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab03){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab03_%s Bias by Model and Validation Proportion.tex", Yi_level))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}


# Table 4: Normalized Bias by Model and Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=bias_norm) %>%
  group_by(Y, Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab04 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rrlrrrrr", 
      caption=sprintf("Normalized Bias Summary Statistics of $\\beta_{t}$, $t=$ %s, by Model and Proportion of Validation Samples.
      Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab04[[Yi_level]] <- tab_i
  attr(tab04[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab04){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab04_%s Normalized Bias by Model and Validation Proportion.tex", Yi_level))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}
  

# Table 5: MSE by Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=mse_mean) %>%
  group_by(Y, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab05 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rlrrrrr", 
      caption=sprintf("MSE Summary Statistics of $\\beta_{t}$, $t=$ %s, by Proportion of Validation Samples.
      Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab05[[Yi_level]] <- tab_i
  attr(tab05[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab05){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab05_%s MSE by Validation Proportion.tex", Yi_level))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}


# Table 6: MSE by Model and Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=mse_mean) %>%
  group_by(Y, Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab06 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rrlrrrrr", 
      caption=sprintf("MSE Summary Statistics of $\\beta_{t}$, $t=$ %s, by Model and Proportion of Validation Samples.
      Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab06[[Yi_level]] <- tab_i
  attr(tab06[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab06){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab06_%s MSE by Model and Validation Proportion.tex", Yi_level))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}


# Table 7: Coverage by Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=coverage_mean) %>%
  group_by(Y, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab07 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rlrrrrr", 
      caption=sprintf("Coverage Summary Statistics of $\\beta_{t}$, $t=$ %s, by Proportion of Validation Samples.
      Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab07[[Yi_level]] <- tab_i
  attr(tab07[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab07){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab07_%s Coverage by Validation Proportion.tex", Yi_level))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}


# Table 8: Coverage by Model and Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=coverage_mean) %>%
  group_by(Y, Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab08 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rrlrrrrr", 
      caption=sprintf("Coverage Summary Statistics of $\\beta_{t}$, $t=$ %s, by Model and Proportion of Validation Samples.
      Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab08[[Yi_level]] <- tab_i
  attr(tab08[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab08){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab08_%s Coverage by Model and Validation Proportion.tex", Yi_level))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}