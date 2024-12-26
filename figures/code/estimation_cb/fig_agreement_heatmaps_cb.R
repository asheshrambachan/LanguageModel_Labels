# Figure: Variation in pairwise agreement between large language model labels across prompting strategies on congressional legislation.
# Dec 10, 2024
# Code based on headlines/code/produce_figures/heatmaps.R

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/estimation_cb")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "estimation_cb/Data/bills_llm.csv")
fig_path <- file.path(fig_dir, "fig_agreement_heatmaps_cb.jpeg")
fig_width <- 8.5
fig_height <- 5.25

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5-Turbo", 
  "gpt-4o-2024-05-13"="GPT-4o"
)
prompt_labels_values <- c(
  `1`="Base: Fill in Blank", 
  `2`="Base: JSON",
  `7`="COT: Careful", 
  `8`="COT: Step-by-step", 
  `9`="COT: Explanation",
  `3`="Persona: Political Analyst", 
  `4`="Persona: Political Scientist",
  `5`="Persona: US Politics Expert",
  `6`="Persona: Research Assistant",
  `10`="Few-Shot: Set 1",
  `11`="Few-Shot: Set 2",
  `12`="Few-Shot: Set 3"
)

# Load and format data
data <- read.csv(data_path) %>%
  rename(c(bill_id=BillID, prompt=PromptingStrategyID, model=Model, Yllm=MajorLLM)) %>%
  select(c(bill_id, prompt, model, Yllm)) %>%
  mutate(
    model = recode_factor(model, !!!model_labels_levels),
    prompt = recode_factor(prompt, !!!prompt_labels_values)
  ) %>%
  tidyr::pivot_wider(id_cols=c(bill_id, model), names_from=prompt, values_from=Yllm)

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

# Iterate over models and compute the agreement_matrix
agreement_matrices <- list()
for (curr_model in unique(data$model)) {
  datasets <- data %>% 
    filter(model==curr_model)
  
  # Calculate and store agreement matrix
  agreement_df <- create_agreement_matrix(datasets)
  agreement_df$model <- curr_model
  agreement_matrices[[curr_model]] <- agreement_df
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
  guides(fill = guide_colourbar(title.vjust = .8)) +
  theme(panel.spacing = unit(0.75, "cm", data = NULL))


# Save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))
