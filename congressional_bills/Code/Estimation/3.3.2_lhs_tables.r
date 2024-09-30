require(dplyr)
require(kableExtra)

# Directories 
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/LHS")
tables_dir <- file.path(repo_dir, "Tables/Estimation/LHS")
dir.create(tables_dir, showWarnings=FALSE, recursive = TRUE)
path_data_5k <- file.path(data_dir, "lhs_5k_llm_human_debiased_averaged.csv")

# Factor labels and levels
proportion_levels <- c(0.05, 0.10, 0.25, 0.50)
proportion_labels <- sprintf("%s\\%%", proportion_levels*100)
regression_levels <- c("5k_Yllm_V", "train_Yhuman_V", "Ytilde_V")
regression_labels <- c("LLM", "Human Validation", "Debiased")
V_levels <- c("Democrat", "Senate", "DW1")
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13")
model_labels <- c("GPT-3.5", "GPT-4o")

# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)

# Load data
data_5k <- read.csv(path_data_5k) %>%
  rename(proportion=train_proportion) %>%
  filter(coef_name!="(Intercept)") %>%
  mutate(
    bias_norm = bias_mean/coef_sd, 
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
tab01 <- data_5k %>%
  mutate(statistic=bias_mean) %>%
  group_by(`Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) %>% 
  kable(
    align="rlrrrrr", 
    caption="Bias Summary Statistics of $\\beta$ by Proportion of Validation Samples. Proxy on the LHS: $Y = \\alpha + \\beta V$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab01 Bias by Validation Proportion.tex")
save_kable(tab01, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 2: Normalized Bias by Validation Proportion
tab02 <- data_5k %>%
  mutate(statistic=bias_norm) %>%
  group_by(`Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) %>% 
  kable(
    align="rlrrrrr",
    caption="Normalized Bias Summary Statistics of $\\beta$ by Proportion of Validation Samples. Proxy on the LHS: $Y = \\alpha + \\beta V$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab02 Normalized Bias by Validation Proportion.tex")
save_kable(tab02, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 3: Bias by Model and Validation Proportion
tab03 <- data_5k %>%
  mutate(statistic=bias_mean) %>%
  group_by(Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) %>%
  kable(
    align="lrlrrrrr", 
    caption="Bias Summary Statistics by Model and Proportion of Validation Samples for $\\beta$. Proxy on the LHS: $Y = \\alpha + \\beta V$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab03 Bias by Model and Validation Proportion.tex")
save_kable(tab03, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 4: Normalized Bias by Model and Validation Proportion
tab04 <- data_5k %>%
  mutate(statistic=bias_norm) %>%
  group_by(Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) %>%
  kable(
    align="lrlrrrrr", 
    caption="Normalized Bias Summary Statistics by Model and Proportion of Validation Samples for $\\beta$. Proxy on the LHS: $Y = \\alpha + \\beta V$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  )

# save
tab_path <- file.path(tables_dir, "tab04 Normalized Bias by Model and Validation Proportion.tex")
save_kable(tab04, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 5: MSE by Validation Proportion
tab05 <- data_5k %>%
  mutate(statistic=mse_mean) %>%
  group_by(`Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop") %>%
  kable(
    align="rlrrrrr", 
    caption="MSE Summary Statistics of $\\beta$ by Proportion of Validation Samples. Proxy on the LHS: $Y = \\alpha + \\beta V$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab05 MSE by Validation Proportion.tex")
save_kable(tab05, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 6: MSE by Model and Validation Proportion
tab06 <- data_5k %>%
  mutate(statistic=mse_mean) %>%
  group_by(Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop") %>%
  kable(
    align="lrlrrrrr", 
    caption="MSE Summary Statistics by Model and Proportion of Validation Samples for $\\beta$. Proxy on the LHS: $Y = \\alpha + \\beta V$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab06 MSE by Model and Validation Proportion.tex")
save_kable(tab06, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 7: Coverage by Validation Proportion
tab07 <- data_5k %>%
  mutate(statistic=coverage_mean) %>%
  group_by(`Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop") %>%
  kable(
    align="rllrrrrr", 
    caption="Coverage Summary Statistics of $\\beta$ by Proportion of Validation Samples. Proxy on the LHS: $Y = \\alpha + \\beta V$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab07 Coverage by Validation Proportion.tex")
save_kable(tab07, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 8: Coverage by Model and Validation Proportion
tab08 <- data_5k %>%
  mutate(statistic=coverage_mean) %>%
  group_by(Model, `Validation Proportion`, Proxy) %>%
  summarise(
    "Mean" = mean(statistic),
    "SD" = sd(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop") %>%
  kable(
    align="lrlrrrrr", 
    caption="Coverage Summary Statistics by Model and Proportion of Validation Samples for $\\beta$. Proxy on the LHS: $Y = \\alpha + \\beta V$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab08 Coverage by Model and Validation Proportion.tex")
save_kable(tab08, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))
