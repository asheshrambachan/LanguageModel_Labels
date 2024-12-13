# Table: Variation in point estimates across large language models and prompting strategies on Congressional bills.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
tab_dir <- file.path(repo_dir, "tables/output/cb") 
dir.create(tab_dir, showWarnings=FALSE, recursive = TRUE)

# Data and table paths
data_bills_path <- file.path(repo_dir, "cb_estimation/Data/bills.csv")
data_llm_path <- file.path(repo_dir, "cb_estimation/Data/lhs_10k_llm.csv")
tab_path <- file.path(tab_dir, "tab_point_est_cb_lhs.tex")

# Load required packages quietly and custom functions
require(dplyr, warn.conflicts = FALSE)
require(kableExtra, warn.conflicts = FALSE)

# Factor labels and levels
V_levels <- c("Democrat", "Senate", "DW1")
Y_labels_levels <- c(
  `3` ="Health", 
  `14`="Banking, Finance, and Domestic Commerce", 
  `15`="Defense", 
  `19`="Government Operations", 
  `20`="Public Lands and Water Management"
)
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o"
)

# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)

# Load data
data_llm <- read.csv(data_llm_path) %>%
  mutate(
    model = recode_factor(model, !!!model_labels_levels),
    V = factor(V, levels=V_levels),
    Y = recode_factor(Y, !!!Y_labels_levels)
  ) %>%
  filter(coef_name!="(Intercept)") %>%
  mutate(statistic=coef) %>%
  group_by(V, Y) %>%
  summarise(
    "Mean" = mean(statistic),
    "Median" = median(statistic),
    "5\\%" = quantile(statistic, probs[1]),
    "95\\%" = quantile(statistic, probs[2]),
    .groups = "drop"
  ) 

# Load bills data to get sample averages
data_bills <- read.csv(data_bills_path) %>%
  group_by(MajorText) %>%
  summarise(count = n()) %>%
  mutate(share = count / sum(count)) %>%
  select(MajorText, share) %>%
  rename(
    Y=MajorText, 
    "Sample Average"=share
  )

data <- data_llm %>% 
  merge(data_bills, by=c("Y")) %>%
  arrange(Y, V) %>%
  rename(
    "Policy Topic"=Y, 
    "Covariate"=V
  )

# Generate latex tables
tab <- data %>%
  kable(digits=3, linesep = "", escape=F, booktabs=T, format = "latex") %>%
  kable_styling(latex_options = "hold_position") %>%
  row_spec(3, hline_after = TRUE, extra_latex_after = "%")  %>%
  row_spec(6, hline_after = TRUE, extra_latex_after = "%") %>%
  row_spec(9, hline_after = TRUE, extra_latex_after = "%") %>%
  row_spec(12, hline_after = TRUE, extra_latex_after = "%") %>%
  add_header_above(c(" ", " ", "Point Estimates" = 4, " "), italic=T)

# Reformat table header
tab <- gsub(
  "\\\\multicolumn\\{1\\}\\{c\\}\\{\\\\em\\{ \\}\\} & \\\\multicolumn\\{1\\}\\{c\\}\\{\\\\em\\{ \\}\\} & \\\\multicolumn\\{4\\}\\{c\\}\\{\\\\em\\{Point Estimates\\}\\} & \\\\multicolumn\\{1\\}\\{c\\}\\{\\\\em\\{ \\}\\} \\\\",
  "\\\\multirow{2}{*}{Policy Topic} & \\\\multirow{2}{*}{Covariate} & \\\\multicolumn{4}{c}{\\\\textit{Point Estimates}} & Sample \\\\",
  tab
)

tab <- gsub(
  "Policy Topic & Covariate & Mean & Median & 5\\\\% & 95\\\\% & Sample Average\\\\",
  "& & Mean & Median & 5\\\\% & 95\\\\% & Average\\\\",
  tab
)

tab <- gsub(
  "Public Lands and Water Management",
  "Public Lands \\\\& Water Management",
  tab
)

tab <- gsub(
  "Banking, Finance, and Domestic Commerce",
  "Banking, Finance \\\\& Domestic Com.",
  tab
)

tab <- gsub("\\\\begin\\{table\\}\\[!h\\]", "", tab)
tab <- gsub("\\\\centering", "", tab)
tab <- gsub("\\\\end\\{table\\}", "", tab)

# save
save_kable(tab, file = tab_path)
cat(sprintf("Saved %s\n", tab_path))
