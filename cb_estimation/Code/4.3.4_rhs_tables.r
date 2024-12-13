require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Directories 
repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation/RHS")
tables_dir <- file.path(repo_dir, "Tables/Estimation/RHS/Validation_Prop_10")
dir.create(tables_dir, showWarnings=FALSE, recursive = TRUE)


path_data_bills <- file.path(data_dir, "../bills.csv")
path_data_llm <- file.path(data_dir, "rhs_10k_llm.csv")
path_data_5k <- file.path(data_dir, "rhs_5k_llm_human_debiased_averaged.csv")

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
Y_levels <- c(3, 14, 15, 19, 20, "Other")
Y_labels <- c( "Health", "Banking, Finance, and Domestic Commerce", "Defense", "Government Operations", "Public Lands and Water Management", "Other")
names(Y_levels) <- Y_labels
names(Y_labels) <- Y_levels
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13")
model_labels <- c("GPT-3.5", "GPT-4o")
regression_levels <- c("5k_V_Yllm", "train_V_Yhuman", "alpha_star")
regression_labels <- c("Plug-In", "Validation", "Debiased")

# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)

# Table A6: Variation in point estimates
data_llm <- read.csv(path_data_llm) %>%
  mutate(
    model = factor(model, levels=model_levels, labels=model_labels),
    V = factor(V, levels=V_levels),
    Y = factor(coef_name, levels=Y_levels, labels=Y_labels)
  ) %>%
  filter(coef_name!="Other") %>%
  mutate(statistic=coef) %>%
  group_by(V, Y) %>%
  summarise(
    "Mean" = mean(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  )

data_bills <- read.csv(path_data_bills) %>%
  mutate(
    Democrat = as.numeric(Party=="Democrat"),
    Senate = as.numeric(Chamber=="Senate")
  ) %>%
  summarise(
    Democrat = mean(Democrat),
    Senate = mean(Senate),
    DW1 = mean(DW1),
    ) %>%
  tidyr::pivot_longer(cols = everything(), names_to = "V", values_to = "Sample Average")

tabA6 <- data_llm %>% 
  merge(data_bills, by=c("V")) %>%
  arrange(V, Y) %>%
  rename("Covariate"=V, "Policy Topic"=Y) %>%
  kable(
    caption="Variation in point estimates across large language models and prompting strategies on Congressional bills, using the economic concept as a covariate.",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex"
  ) %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(5, hline_after = TRUE, extra_latex_after = "%")  %>%
  row_spec(10, hline_after = TRUE, extra_latex_after = "%") %>%
  add_header_above(c(" ", " ", "Point Estimates" = 4, " "), italic=T)

# save
tab_path <- file.path(tables_dir, "../Table A6.tex")
save_kable(tabA6, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

# Load simulation data
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

# Table A7: Normalized Bias and Coverage, Val Prop 10
tab_normalized_bias <- data_5k %>%
  mutate(statistic=bias_norm) %>%
  group_by(Model, Proxy) %>%
  summarise(
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

tab_coverage <-data_5k %>%
  mutate(statistic=coverage_mean) %>%
  group_by(Model, Proxy) %>%
  summarise(
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

# Model GPT-3.5
tabA7_a <- bind_rows(tab_normalized_bias, tab_coverage) %>%
  filter(
    Model=="GPT-3.5",
    Proxy!="Validation"
  ) %>%
  select(Proxy, Median, `5\\%`, `95\\%`) %>%
  rename("Regression Coefficient"=Proxy) %>%
  kable(
    caption="GPT-3.5-Turbo",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex", label=NULL
  ) %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(2, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 2, italic=T, bold=F) %>%
  pack_rows("Coverage", 3, 4, italic=T, bold=F)

# save
tab_path <- file.path(tables_dir, "Table A7 (a).tex")
save_kable(tabA7_a, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))

# Model GPT-4o
tabA7_b <- bind_rows(tab_normalized_bias, tab_coverage) %>%
  filter(
    Model=="GPT-4o",
    Proxy!="Validation"
  ) %>%
  select(Proxy, Median, `5\\%`, `95\\%`) %>%
  rename("Regression Coefficient"=Proxy) %>%
  kable(
    caption="GPT-4o",
    digits=3, linesep = "", escape=F, booktabs=T, format = "latex", label=NULL
  ) %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(2, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 2, italic=T, bold=F) %>%
  pack_rows("Coverage", 3, 4, italic=T, bold=F)

# save
tab_path <- file.path(tables_dir, "Table A7 (b).tex")
save_kable(tabA7_b, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


