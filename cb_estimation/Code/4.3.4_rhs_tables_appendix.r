require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Directories 
repo_dir <- "~/Documents/LanguageModel_Labels/cb_estimation"
data_dir <- file.path(repo_dir, "Data/RHS")
tables_dir <- file.path(repo_dir, "Tables/RHS")
dir.create(tables_dir, showWarnings=FALSE, recursive = TRUE)
path_data_5k <- file.path(data_dir, "rhs_5k_llm_human_debiased_averaged.csv")

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
Y_levels <- c(3, 14, 15, 19, 20, "Other")
Y_labels <- c( "Health", "Banking, Finance, and Domestic Commerce", "Defense", "Government Operations", "Public Lands and Water Management", "Other")
names(Y_levels) <- Y_labels
names(Y_labels) <- Y_levels
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13")
model_labels <- c("GPT-3.5", "GPT-4o")
regression_levels <- c("5k_V_Yllm", "train_V_Yhuman", "Vtilde_Ytilde")
regression_labels <- c("LLM", "Validation", "Debiased")
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

# Table 1: Bias by Model and Validation Proportion
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

tab01 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rrlrrrrr", 
      caption=sprintf("Bias Summary Statistics of $\\beta_{t}$, $t=$ %s, by Model and Proportion of Validation Samples. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab01[[Yi_level]] <- tab_i
  attr(tab01[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab01){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab01_%s Bias by Model and Validation Proportion - %s.tex", Yi_level, Y_labels[Yi_level]))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}



# Table 1 (Pooled): Bias by Model and Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=bias_mean) %>%
  group_by(Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab01_pooled <- tab_data %>% 
  kable(
    align="rrlrrrrr", 
    caption="Bias Summary Statistics by Model and Proportion of Validation Samples, Pooled Across All $\\beta_{t}$ Coefficients. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab01_pooled Bias by Model and Validation Proportion.tex")
save_kable(tab01_pooled, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 2: Normalized Bias by Model and Validation Proportion
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

tab02 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rrlrrrrr", 
      caption=sprintf("Normalized Bias Summary Statistics of $\\beta_{t}$, $t=$ %s, by Model and Proportion of Validation Samples. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab02[[Yi_level]] <- tab_i
  attr(tab02[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab02){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab02_%s Normalized Bias by Model and Validation Proportion - %s.tex", Yi_level, Y_labels[Yi_level]))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}

# Table 2 (Pooled): Normalized Bias by Model and Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=bias_norm) %>%
  group_by(Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab02_pooled <- tab_data %>% 
  kable(
    align="rrlrrrrr", 
    caption="Normalized Bias Summary Statistics by Model and Proportion of Validation Samples, Pooled Across All $\\beta_{t}$ Coefficients. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab02_pooled Normalized Bias by Model and Validation Proportion.tex")
save_kable(tab02_pooled, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 3: MSE by Model and Validation Proportion
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

tab01 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rrlrrrrr", 
      caption=sprintf("MSE Summary Statistics of $\\beta_{t}$, $t=$ %s, by Model and Proportion of Validation Samples. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab01[[Yi_level]] <- tab_i
  attr(tab01[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab01){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab03_%s MSE by Model and Validation Proportion - %s.tex", Yi_level, Y_labels[Yi_level]))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}


# Table 3 (Pooled): MSE by Model and Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=mse_mean) %>%
  group_by(Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab03_pooled <- tab_data %>% 
  kable(
    align="rrlrrrrr", 
    caption="MSE Summary Statistics by Model and Proportion of Validation Samples, Pooled Across All $\\beta_{t}$ Coefficients. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab03_pooled MSE by Model and Validation Proportion.tex")
save_kable(tab03_pooled, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))



# Table 4: Coverage by Model and Validation Proportion
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

tab02 <- list()
for (Yi_label in unique(tab_data$Y)){
  Yi_level <- Y_levels[Yi_label]
  
  tab_i <- tab_data %>% 
    filter(Y == Yi_label) %>%
    select(!Y) %>%
    kable(
      align="rrlrrrrr", 
      caption=sprintf("Coverage Summary Statistics of $\\beta_{t}$, $t=$ %s, by Model and Proportion of Validation Samples. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.", Yi_label),
      digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
    ) 
  
  tab02[[Yi_level]] <- tab_i
  attr(tab02[[Yi_level]], "Y") <- Yi_level
}

# save
for (tab_i in tab02){
  Yi_level <- attr(tab_i, "Y")
  tab_path <- file.path(tables_dir, sprintf("tab04_%s Coverage by Model and Validation Proportion - %s.tex", Yi_level, Y_labels[Yi_level]))
  save_kable(tab_i, file = tab_path)
  cat(sprintf("Saved %s\n", tab_path))
}



# Table 4 (Pooled): Coverage by Model and Validation Proportion
tab_data <- data_5k %>%
  mutate(statistic=coverage_mean) %>%
  group_by(Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab04_pooled <- tab_data %>% 
  kable(
    align="rrlrrrrr", 
    caption="Coverage Summary Statistics by Model and Proportion of Validation Samples, Pooled Across All $\\beta_{t}$ Coefficients. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab04_pooled Coverage by Model and Validation Proportion.tex")
save_kable(tab04_pooled, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))
