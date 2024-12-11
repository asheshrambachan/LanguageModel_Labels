# Figure: Two examples of GPT-4o completions that exactly match original financial news headlines.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "congressional_bills/Figures")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "headlines_completion/Data/headlines_completion_similarity.csv")
fig_path <- file.path(fig_dir, "fig02_headlines_completion_exact_gpt4o_without_date.tex")

# Factor labels and levels
prompt_labels_levels <- c(
  "False"="w/o date restriction", 
  "True"="w/ date restriction"
)
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o",
  "gpt-4o-mini-2024-07-18"="GPT-4o-mini"
)

# Load and format data
data <- read.csv(data_path) %>%
  rename("prompt"=add_date) %>%
  mutate(
    Model = recode_factor(model, !!!model_labels_levels),
    Prompt = recode_factor(prompt, !!!prompt_labels_levels),
    TextSimilarity = if_else(TextSimilarity=="True", 1, 0)
  ) %>%
  filter(
    TextSimilarity==1,
    Model=="GPT-4o",
    Prompt=="w/o date restriction"
  ) %>%
  select(c(headline_clean, headline_llm_clean)) %>%
  rename(
    "Original Headline" = headline_clean,
    "GPT-4o" = headline_llm_clean
  )

# Draw 2 samples
sample_index <- c(51, 3)
data_sample <- data[sample_index, ] 

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
    "    \\textbf{GPT-4o}: ", gpt, "\n",
    "    \\end{tcolorbox}\n",
    "    \\end{minipage}\n",
    "\\end{tcolorbox}"
  )
}

# Plot figure
fig <- apply(data_sample, 1, function(row) {
    create_latex_row(row["Original Headline"], row["GPT-4o"])
  }) %>%
  paste(collapse = "\n") # Combine all rows into a single LaTeX string

# Save figure
cat(fig, file = fig_path)
cat(sprintf("Saved %s\n", fig_path))