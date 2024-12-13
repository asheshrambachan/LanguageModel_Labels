require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Directories 
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/LHS")
tables_dir <- file.path(repo_dir, "Tables/Estimation/LHS/Validation_Prop_10")
dir.create(tables_dir, showWarnings=FALSE, recursive = TRUE)

path_data_bills <- file.path(data_dir, "../bills.csv")
path_data_llm <- file.path(data_dir, "lhs_10k_llm.csv")
path_data_human <- file.path(data_dir, "lhs_10k_human.csv")
path_data_5k <- file.path(data_dir, "lhs_5k_llm_human_debiased_averaged.csv")

# Factor labels and levels
proportion_levels <- c(0.05, 0.10, 0.25, 0.50)
proportion_labels <- sprintf("%s\\%%", proportion_levels*100)
regression_levels <- c("5k_Yllm_V", "train_Yhuman_V", "Ytilde_V")
regression_labels <- c("Plug-In", "Validation", "Debiased")
V_levels <- c("Democrat", "Senate", "DW1")
Y_levels <- c(3, 14, 15, 19, 20)
Y_labels <- c( "Health", "Banking, Finance, and Domestic Commerce", "Defense", "Government Operations", "Public Lands and Water Management")
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13")
model_labels <- c("GPT-3.5", "GPT-4o")

# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)

# Load averaged simulation data
data_5k <- read.csv(path_data_5k) %>%
  rename(proportion=train_proportion) %>%
  filter(
    coef_name!="(Intercept)",
    # proportion==0.1
    ) %>%
  mutate(
    bias_norm = bias_mean/coef_sd, 
    V = factor(V, levels=V_levels),
    model = factor(model, levels=model_levels, labels=model_labels),
    regression = factor(regression, levels=regression_levels, labels=regression_labels),
    proportion = factor(proportion, levels=proportion_levels, labels=proportion_labels)
  ) %>%
  rename(c(
    "Proxy" = regression,
    "Model" = model)
  ) 

tab_normalized_bias <- data_5k %>%
  mutate(statistic=bias_norm) %>%
  group_by(Model, Proxy, proportion) %>%
  summarise(
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) %>%
  mutate(Statistic="Normalized Bias")

tab_coverage <- data_5k %>%
  mutate(statistic=coverage_mean) %>%
  group_by(Model, Proxy, proportion) %>%
  summarise(
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop") %>%
  mutate(Statistic="Coverage")

tab <- bind_rows(tab_normalized_bias, tab_coverage)

# Table 4: 
# (a) GPT-3.5
tab4_a <- tab %>%
  filter(
    Model=="GPT-3.5",
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
tab_path <- file.path(tables_dir, "Table 4 (a).tex")
save_kable(tab4_a, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


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

# Table A4: Normalized Bias and Coverage, Val Prop 10, GPT-3.5
# (a) Plug-In
tabA4_a <- tab %>%
  filter(
    Model=="GPT-3.5",
    Proxy=="Plug-In"
  ) %>%
  select(proportion, Median, `5\\%`, `95\\%`) %>%
  rename("Validation Prop."=proportion) %>%
  kable(
    caption="Plug-In regression",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex", label=NULL
  ) %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(4, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 4, italic=T, bold=F) %>%
  pack_rows("Coverage", 5, 8, italic=T, bold=F)

# save
tab_path <- file.path(tables_dir, "../Table A4 (a).tex")
save_kable(tabA4_a, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

# Table A4: Normalized Bias and Coverage, Val Prop 10, GPT-3.5
# (a) Plug-In
tabA4_a <- tab %>%
  filter(
    Model=="GPT-3.5",
    Proxy=="Plug-In"
  ) %>%
  select(proportion, Median, `5\\%`, `95\\%`) %>%
  rename("Validation Prop."=proportion) %>%
  kable(
    caption="Plug-In regression",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex", label=NULL
  ) %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(4, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 4, italic=T, bold=F) %>%
  pack_rows("Coverage", 5, 8, italic=T, bold=F)

# save
tab_path <- file.path(tables_dir, "../Table A4 (a).tex")
save_kable(tabA4_a, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

# (b) Debiased
tabA4_b <- tab %>%
  filter(
    Model=="GPT-3.5",
    Proxy=="Debiased"
  ) %>%
  select(proportion, Median, `5\\%`, `95\\%`) %>%
  rename("Validation Prop."=proportion) %>%
  kable(
    caption="Debiased regression",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex", label=NULL
  ) %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(4, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 4, italic=T, bold=F) %>%
  pack_rows("Coverage", 5, 8, italic=T, bold=F)

# save
tab_path <- file.path(tables_dir, "../Table A4 (b).tex")
save_kable(tabA4_b, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

# Table A5: Normalized Bias and Coverage, Val Prop 10, GPT-4o
# (a) Plug-In
tabA5_a <- tab %>%
  filter(
    Model=="GPT-4o",
    Proxy=="Plug-In"
  ) %>%
  select(proportion, Median, `5\\%`, `95\\%`) %>%
  rename("Validation Prop."=proportion) %>%
  kable(
    caption="Plug-In regression",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex", label=NULL
  ) %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(4, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 4, italic=T, bold=F) %>%
  pack_rows("Coverage", 5, 8, italic=T, bold=F)

# save
tab_path <- file.path(tables_dir, "../Table A5 (a).tex")
save_kable(tabA5_a, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

# (b) Debiased
tabA5_b <- tab %>%
  filter(
    Model=="GPT-4o",
    Proxy=="Debiased"
  ) %>%
  select(proportion, Median, `5\\%`, `95\\%`) %>%
  rename("Validation Prop."=proportion) %>%
  kable(
    caption="Debiased regression",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex", label=NULL
  ) %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(4, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 4, italic=T, bold=F) %>%
  pack_rows("Coverage", 5, 8, italic=T, bold=F)

# save
tab_path <- file.path(tables_dir, "../Table A5 (b).tex")
save_kable(tabA5_b, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))