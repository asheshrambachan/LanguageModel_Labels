# Dec 17, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/estimation_headlines") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_path <- file.path(repo_dir, "headlines/data/step9_reg_results/summary_stat_data.csv")
tab_path <- file.path(tab_dir, "tab_point_est_headlines_realized_q1_confidence_positive.tex")

# Load required packages quietly
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

data <- read.csv(data_path) %>% 
  filter(
    return_type == "Realized Returns",
    question == "q1",
    mag_v_conf == "confidence",
    V == "Positive"
  ) %>%
  select(W, Mean, Median, CI05, CI95, Sample.Average) %>%
  rename(c(
    "5th Percentile"=CI05,
    "95th Percentile"=CI95,
    "Sample Average"=Sample.Average
  )) %>%
  as.data.frame(.)
data_colnames <- c("Point Estimates", as.character(data$W)) # "Return Horizon"=W,
data <- data %>% select(!W) %>% t(.) 

tab <- data %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex", col.names = data_colnames) %>%
  add_header_above(c(" ", "Return Horizon" = 3), italic=T) %>%
  row_spec(4, hline_after = TRUE, extra_latex_after = "%")

# Save tables
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))
