# Dec 17, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/estimation_cb") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "estimation_cb/Data/rhs_5k_plugin_validation_debiased_averaged_summary_stat.csv")
tab_path <- file.path(tab_dir, "tab_summary_stat_gpt3_cb_rhs_all_prop_debiased.tex")

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
    proportion = recode_factor(proportion, !!!proportion_labels_levels)
  ) %>%
  filter(
    statistic_name %in% c("bias_norm", "coverage_mean"),
    regression=="Debiased",
    model=="GPT-3.5",
    proportion!="2.5%"
  ) %>%
  select(proportion, Median, CI05, CI95) %>%
  rename(c(
    "5\\%"=CI05,
    "95\\%"=CI95,
    "Validation Prop."=proportion
  ))

tab <- data %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  row_spec(4, hline_after = TRUE, extra_latex_after = "%") %>%
  pack_rows("Normalized Bias", 1, 4, italic=T, bold=F)  %>%
  pack_rows("Coverage", 5, 8, italic=T, bold=F)

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
tab <- gsub(
  "\\\\begin\\{tabular\\}\\{lrrr\\}", 
  "\\\\begin\\{tabular\\}\\{r|rrr\\}", 
  tab)

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))


