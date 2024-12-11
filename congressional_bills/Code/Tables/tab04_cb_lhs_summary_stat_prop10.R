# Table: Summary statistics for normalized bias and coverage across Monte Carlo simulations based on Congressional legislation.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
tab_dir <- file.path(repo_dir, "Tables") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <-  file.path(repo_dir, "Data/Estimation/lhs_5k_llm_human_debiased_averaged.csv")
tab_a_path <- file.path(tab_dir, "tab04a_cb_lhs_summary_stat_prop10_gpt35.tex")
tab_b_path <- file.path(tab_dir, "tab04b_cb_lhs_summary_stat_prop10_gpt4o.tex")

# Load required packages quietly and custom functions
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o"
)
regression_labels_levels <- c(
  "5k_Yllm_V" = "Plug-In",
  "train_Yhuman_V" = "Validation",
  "Ytilde_V" = "Debiased"
)
proportion_levels <- c(0.05, 0.10, 0.25, 0.50)
proportion_labels <- sprintf("%s\\%%", proportion_levels*100)

# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)

# Load averaged simulation data
data <- read.csv(data_path) %>%
  rename(proportion=train_proportion) %>%
  filter(
    coef_name!="(Intercept)"
  ) %>%
  mutate(
    bias_norm = bias_mean/coef_sd, 
    V = factor(V, levels=V_levels),
    model = recode_factor(model, !!!model_labels_levels),
    regression = recode_factor(regression, !!!regression_labels_levels)
  ) %>%
  rename(c(
    "Proxy" = regression,
    "Model" = model)
  ) %>%
  select(c(Model, Proxy, proportion, bias_norm, coverage_mean)) %>%
  tidyr::pivot_longer(
    cols = c(bias_norm, coverage_mean),
    names_to = "statistic"
    ) %>%
  group_by(Model, Proxy, proportion, statistic) %>%
  summarise(
    "Median" = median(value),
    "5\\%" = quantile(value, probs[1]),
    "95\\%" = quantile(value, probs[2]),
    .groups = "drop"
  ) %>%
  filter(
    proportion==0.10,
    Proxy!="Validation"
  )

# Panel (a)
tab_a <- data %>%
  filter(Model=="GPT-3.5") %>%
  arrange(statistic, Proxy) %>%
  select(Proxy, Median, `5\\%`, `95\\%`) %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(2, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 2, italic=T, bold=F) %>%
  pack_rows("Coverage", 3, 4, italic=T, bold=F)

# save
save_kable(tab_a, file = tab_a_path)
cat(sprintf("Saved %s\n", tab_a_path))


# (b) GPT-4o
tab4_b <- tab %>%
  filter(
    Model=="GPT-4o",
    proportion=="10\\%",
    Proxy!="Validation"
  ) %>%
  select(Median, `5\\%`, `95\\%`) %>%
  kable(
    caption="GPT-3.5-Turbo",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex", label=NULL
  ) %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(2, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 2, italic=T, bold=F) %>%
  pack_rows("Coverage", 3, 4, italic=T, bold=F)

# save
tab_path <- file.path(tables_dir, "Table 4 (b).tex")
save_kable(tab4_b, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

