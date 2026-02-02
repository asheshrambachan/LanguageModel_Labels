# Table: Summary statistics for normalized bias and coverage for Monte Carlo simulations on congressional legislation using policy topic as a covariate, GPT-3.5.
# Dec 16, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/estimation_legislation") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <-  file.path(repo_dir, "estimation_legislation/data/rhs_5k_plugin_validation_debiased_averaged_summary_stat.csv")
tab_path <- file.path(tab_dir, "tab_summary_stat_gpt3_cb_rhs_prop10.tex")

# Load required packages quietly and custom functions
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Factor labels and levels
regression_levels <- c("Plug-In", "Validation", "Debiased")
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o",
  "gpt-5-mini"="GPT-5-mini",
  "gpt-5-nano"="GPT-5-nano"
)
proportion_labels_levels <- c(
  `0.025` = "2.5%",
  `0.05` = "5%",
  `0.10` = "10%",
  `0.25` = "25%",
  `0.50` = "50%"
)

# Load averaged simulation data
data <- read.csv(data_path) %>%
  mutate(
    regression = factor(regression, levels=regression_levels),
    model = recode_factor(model, !!!model_labels_levels),
    proportion = recode_factor(proportion, !!!proportion_labels_levels),
  ) %>%
  filter(
    statistic_name %in% c("bias_norm", "coverage_mean"),
    regression!="Validation",
    model=="GPT-3.5",
    proportion=="10%"
  ) %>%
  arrange(statistic_name, regression) %>%
  select(regression, Median, CI05, CI95) %>%
  rename(c(
    "5\\%"="CI05",
    "95\\%"="CI95",
    " "=regression
  ))

tab <- data %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
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

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


