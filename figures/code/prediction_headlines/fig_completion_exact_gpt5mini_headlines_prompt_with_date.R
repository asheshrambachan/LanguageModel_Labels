# Figure: Examples of GPT-5-mini completions with date restriction that exactly match original financial news headlines.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/prediction_headlines")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "prediction_headlines/Data/completion_exact_examples.csv")
fig_path <- file.path(fig_dir, "fig_completion_exact_gpt5mini_headlines_prompt_with_date.tex")

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)

# Load and format data
data <- read.csv(data_path) %>%
  filter(
    Model=="GPT-5-mini",
    Prompt=="Prompt with date restriction"
  ) %>%
  select(c(headline_clean, headline_llm_clean)) %>%
  rename(
    "Original Headline" = headline_clean,
    "GPT-5-mini" = headline_llm_clean
  )

# Draw 2 samples
data_sample <- data %>% slice(1:2)

# Function to create the figure for one row
create_latex_row <- function(original, gpt) {
  paste0(
    "\\begin{tcolorbox}[colback=white,colframe=black!75!white] \n",
    "    \\begin{minipage}{0.475\\textwidth}\n",
    "    \\centering\n",
    "    \\begin{tcolorbox}[colback=black!5!white,colframe=black!75!white, fontupper=\\small, fontlower=\\small] \n",
    "    \\textbf{Original Headline}: ", original, "\n",
    "    \\end{tcolorbox}\n",
    "    \\end{minipage} \n",
    "    \\hfill\n",
    "    \\begin{minipage}{0.475\\textwidth}\n",
    "    \\centering\n",
    "    \\begin{tcolorbox}[colback=black!5!white,colframe=black!75!white, fontupper=\\small, fontlower=\\small] \n",
    "    \\textbf{GPT-5-mini}: ", gpt, "\n",
    "    \\end{tcolorbox}\n",
    "    \\end{minipage}\n",
    "\\end{tcolorbox}"
  )
}

# Plot figure
fig <- apply(data_sample, 1, function(row) {
  create_latex_row(row["Original Headline"], row["GPT-5-mini"])
}) %>%
  paste(collapse = "\n") # Combine all rows into a single LaTeX string

# Save figure
cat(fig, file = fig_path)
cat(sprintf("Saved %s\n", fig_path))