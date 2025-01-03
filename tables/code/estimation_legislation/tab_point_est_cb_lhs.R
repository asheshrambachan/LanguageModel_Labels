# Table: Variation in point estimates across large language models and prompting strategies on Congressional bills.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/estimation_legislation") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "estimation_legislation/data/lhs_10k_plugin_summary_stat.csv")
tab_path <- file.path(tab_dir, "tab_point_est_cb_lhs.tex")

# Load required packages quietly and custom functions
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Load data
data <- read.csv(data_path) %>%
  rename(c(
    "Policy Topic"=V, 
    "Covariate"=W,
    "Sample Average"=Sample.Average,
    "5\\%"="CI05",
    "95\\%"="CI95"
  )) %>%
  select(!c(statistic_name, SD))

# Generate latex tables
tab <- data %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  row_spec(3, hline_after = TRUE, extra_latex_after = "%")  %>%
  row_spec(6, hline_after = TRUE, extra_latex_after = "%") %>%
  row_spec(9, hline_after = TRUE, extra_latex_after = "%") %>%
  row_spec(12, hline_after = TRUE, extra_latex_after = "%") %>%
  add_header_above(c(" ", " ", "Point Estimates" = 4, " "), italic=T)

# Reformat table header
tab <- gsub(
  "\\\\multicolumn\\{1\\}\\{c\\}\\{\\\\em\\{ \\}\\} & \\\\multicolumn\\{1\\}\\{c\\}\\{\\\\em\\{ \\}\\} & \\\\multicolumn\\{4\\}\\{c\\}\\{\\\\em\\{Point Estimates\\}\\} & \\\\multicolumn\\{1\\}\\{c\\}\\{\\\\em\\{ \\}\\} \\\\",
  "\\\\multirow{2}{*}{Policy Topic} & \\\\multirow{2}{*}{Covariate} & \\\\multicolumn{4}{c}{\\\\textit{Point Estimates}} & Sample\\\\",
  tab
)

tab <- gsub(
  "Policy Topic & Covariate & Mean & Median & 5\\\\% & 95\\\\% & Sample Average\\\\",
  "& & Mean & Median & 5\\\\% & 95\\\\% & Average\\\\",
  tab
)

tab <- gsub(
  "Banking, Finance \\& Domestic Commerce",
  "Banking, Finance \\\\& Domestic Com.",
  tab
)

tab <- gsub(
  "Public Lands \\& Water Management",
  "Public Lands \\\\& Water Management",
  tab
)

# save
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))
