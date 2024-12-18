# Dec 17, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/estimation_cb") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "estimation_cb/Data/lhs_5k_plugin_validation_debiased_averaged_summary_stat.csv")
tab_path <- file.path(tab_dir, "tab_coverage_cb_lhs_prop05_plugin_debiased.tex")

# Load required packages quietly and custom functions
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Factor labels and levels
regression_levels <- c("Plug-In", "Validation", "Debiased")
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o"
)
proportion_labels_levels <- c(
  `0.025` = "2.5\\%",
  `0.05` = "5\\%",
  `0.10` = "10\\%",
  `0.25` = "25\\%",
  `0.50` = "50\\%"
)

# Load averaged simulation data
data <- read.csv(data_path) %>%
  mutate(
    regression = factor(regression, levels=regression_levels),
    model = recode_factor(model, !!!model_labels_levels),
    proportion = recode_factor(proportion, !!!proportion_labels_levels)
  ) %>%
  filter(
    statistic_name %in% c("coverage_mean"),
    regression!="Validation",
    proportion=="5\\%"
  ) %>%
  select(model, regression, Mean, Median, CI05, CI95) %>%
  rename(c(
    Model=model,
    "5\\%"=CI05,
    "95\\%"=CI95,
    Method=regression
  ))

tab <- data %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  row_spec(2, hline_after = TRUE, extra_latex_after = "%")

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))
