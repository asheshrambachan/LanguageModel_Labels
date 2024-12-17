# Figure: Variation in pairwise agreement between large language model labels across prompting strategies on financial news headlines, q1
# Dec 10, 2024
# Code based on headlines/code/produce_figures/heatmaps.R

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/headlines")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
fig_path <- file.path(fig_dir, "fig_agreement_heatmaps_headlines_realized_q1.jpeg")
fig_width <- 9
fig_height <- 4.75

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
model_labels_values <- c(
  "gpt-3.5-turbo"="GPT-3.5", 
  "gpt-4o"="GPT-4o",
  "gpt-4o-mini"="GPT-4o-mini"
)
prompt_labels_values <- c(
  "base_blanks"="Base: Fill in Blank", 
  "base_json"="Base: JSON",
  "cot1"="COT: Careful", 
  "cot3"="COT: Step-by-step", 
  "cot2"="COT: Explanation",
  "persona1"="Persona: Economic Agent", 
  "persona2"="Persona: Finance Expert",
  "persona3"="Persona: Economy Expert",
  "persona4"="Persona: Successful Trader"
)

# Helper function to read datasets
read_datasets <- function(path) {
  data <- NULL
  
  for (curr_prompt in names(prompt_labels_values)){
    file_path <- file.path(path, sprintf("%s.csv", curr_prompt))
    file <- read.csv(file_path) %>% 
      mutate(
        prompt = curr_prompt,
        headline_id = row_number()
      ) %>%
      select(c(headline_id, prompt, headline.type))
    
    if (is.null(data))
      data <- file
    else
      data <- bind_rows(data, file)
  }
  
  data <- data %>%
    mutate(prompt = recode_factor(prompt, !!!prompt_labels_values)) %>%
    tidyr::pivot_wider(id_cols=headline_id, names_from=prompt, values_from=headline.type)
  
  return(data)
}

# Function to calculate agreement matrix
create_agreement_matrix <- function(datasets) {
  agreement_matrix <- expand.grid(
    prompt_x = prompt_labels_values,
    prompt_y = prompt_labels_values
  ) %>%
    mutate(agreement = mapply(
      function(x, y) mean(x == y, na.rm = TRUE) * 100,
      datasets[prompt_x],
      datasets[prompt_y]
    ))
  return(agreement_matrix)
}


# Iterate over combinations and store data
agreement_matrices <- list()
for (model in names(model_labels_values)) {
  path <- file.path(repo_dir, "headlines/data/step6_common_sample/within_model/realized", model, "q1")
  datasets <- read_datasets(path)
  
  # Calculate and store agreement matrix
  agreement_df <- create_agreement_matrix(datasets)
  agreement_df$model <- model_labels_values[model]
  agreement_matrices[[model]] <- agreement_df
}
agreement_matrices <- bind_rows(agreement_matrices)

# Store global min and max
# heatmap_global_min <- min(agreement_matrices$agreement, na.rm = TRUE)
# heatmap_global_max <- max(agreement_matrices$agreement, na.rm = TRUE)

# Plot figure
fig <- agreement_matrices %>%
  ggplot(aes(x=prompt_x, y=prompt_y, fill=agreement)) +
  geom_tile() +
  facet_grid(~ model) 

# Add theme and aesthetics
fig <- fig +
  labs(
    x = "Prompting Strategy", 
    y = "Prompting Strategy", 
    fill = "Pairwise Agreement Percent"
  ) + 
  scale_fill_viridis_c(
    option = "plasma", 
    direction = -1, 
    limits = c(heatmap_global_min, heatmap_global_max)
  ) +
  # Add agreement percentage with appropriate font color for clarity.
  geom_text(aes(
    label = sprintf("%.1f", agreement), 
    color = ifelse(agreement >= 80, "white", "black")
  ), size = 2.7, show.legend = FALSE) + 
  scale_color_identity() +
  theme.heatmap +
  guides(fill = guide_colourbar(title.vjust = .8)) 
# Save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))
