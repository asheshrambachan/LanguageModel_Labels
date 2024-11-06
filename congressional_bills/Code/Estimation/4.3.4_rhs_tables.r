require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Directories 
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/RHS")
tables_dir <- file.path(repo_dir, "Tables/Estimation/RHS/Validation_Prop_10")
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

# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)

# Load data
data_5k <- read.csv(path_data_5k) %>%
  rename(proportion=train_proportion)  %>%
  filter(
    coef_name != "Other",
    proportion==0.1
    ) %>%
  mutate(
    bias_norm = bias_mean/coef_sd, 
    Y = factor(coef_name, levels=Y_levels, labels=Y_labels),
    V = factor(V, levels=V_levels),
    model = factor(model, levels=model_levels, labels=model_labels),
    regression = factor(regression, levels=regression_levels, labels=regression_labels)
  ) %>%
  rename(c(
    "Proxy" = regression,
    "Model" = model)
  )

# Table 1 (Pooled): Bias by Model, Val Prop 10
tab_data <- data_5k %>%
  mutate(statistic=bias_mean) %>%
  group_by(Model, Proxy) %>%
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
    align="llrrrrr", 
    caption="Bias Summary Statistics by Model, Pooled Across All $\\beta_{t}$ Coefficients. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab01_pooled Bias by Model, Val Prop 10.tex")
save_kable(tab01_pooled, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 2 (Pooled): Normalized Bias by Model, Val Prop 10
tab_data <- data_5k %>%
  mutate(statistic=bias_norm) %>%
  group_by(Model, Proxy) %>%
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
    align="llrrrrr", 
    caption="Normalized Bias Summary Statistics by Model, Pooled Across All $\\beta_{t}$ Coefficients. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab02_pooled Normalized Bias by Model, Val Prop 10.tex")
save_kable(tab02_pooled, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))



# Table 3 (Pooled): MSE by Model, Val Prop 10
tab_data <- data_5k %>%
  mutate(statistic=mse_mean) %>%
  group_by(Model, Proxy) %>%
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
    align="llrrrrr", 
    caption="MSE Summary Statistics by Model, Pooled Across All $\\beta_{t}$ Coefficients. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab03_pooled MSE by Model, Val Prop 10.tex")
save_kable(tab03_pooled, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


# Table 4 (Pooled): Coverage by Model, Val Prop 10
tab_data <- data_5k %>%
  mutate(statistic=coverage_mean) %>%
  group_by(Model, Proxy) %>%
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
    align="llrrrrr", 
    caption="Coverage Summary Statistics by Model, Pooled Across All $\\beta_{t}$ Coefficients. Proxy on the RHS: $V = Y^\\top \\beta = \\sum_{t} Y_t \\beta_t$.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) 

# save
tab_path <- file.path(tables_dir, "tab04_pooled Coverage by Model, Val Prop 10.tex")
save_kable(tab04_pooled, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))
