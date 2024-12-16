# Table: Summary statistics for normalized bias and coverage for Monte Carlo simulations on congressional legislation using policy topic as a covariate, GPT-3.5.
# Dec 16, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/cb") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <-  file.path(repo_dir, "estimation_cb/Data/rhs_5k_llm_human_debiased_averaged.csv")
tab_path <- file.path(tab_dir, "tab_summary_stat_gpt3_cb_rhs_prop10.tex")

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
  "5k_V_Yllm" = "Plug-In",
  "train_V_Yhuman" = "Validation",
  "alpha_star" = "Debiased"
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
    coef_name!="Other"
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
    Proxy!="Validation",
    Model=="GPT-3.5"
  ) %>%
  arrange(statistic, Proxy) %>%
  select(Proxy, Median, `5\\%`, `95\\%`)

tab <- data %>%
  rename(" "=Proxy) %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(2, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 2, italic=T, bold=F)  %>%
  pack_rows("Coverage", 3, 4, italic=T, bold=F)

tab <- gsub("\\\\addlinespace\\[0.3em\\]\n", "", tab)
tab <- gsub("\\\\hspace\\{1em\\}", "", tab)
tab <- gsub(
  "\\\\multicolumn\\{4\\}\\{l\\}\\{\\\\textit\\{Normalized Bias\\}\\}", 
  "\\\\multicolumn\\{1\\}\\{l|\\}\\{\\\\textit\\{Normalized Bias\\}\\}", 
  tab)
tab <- gsub(
  "\\\\multicolumn\\{4\\}\\{l\\}\\{\\\\textit\\{Coverage\\}\\}", 
  "\\\\multicolumn\\{1\\}\\{l|\\}\\{\\\\textit\\{Coverage\\}\\}", 
  tab)
tab <- gsub("\\\\begin\\{tabular\\}\\{lrrr\\}", "\\\\begin\\{tabular\\}\\{r|rrr\\}", tab)
tab <- gsub("\\\\begin\\{table\\}\\[!h\\]\n", "", tab)
tab <- gsub("\\\\centering\n", "", tab)
tab <- gsub("\\\\end\\{table\\}", "", tab)

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


