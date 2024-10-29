# Results Bills and LLM
# Sep 23, 2024

repo_dir <- "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir <- file.path(repo_dir, "Data/Estimation") 
fig_dir <- file.path(repo_dir, "Figures/Estimation")
slides_fig_dir <- file.path(repo_dir, "Figures/Figures_For_Slides/CongressionalBills_Estimation")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)
dir.create(slides_fig_dir, showWarnings=FALSE, recursive = TRUE)

# Load required packages quietly and custom functions
suppressPackageStartupMessages({
  require(dplyr)
  require(ggplot2)
  require(lemon)
  require(viridis)
})
source(file.path(repo_dir, "Code/ggplot_theme.r"))

bills <- read.csv(file.path(data_dir, "bills.csv"))

# Fig 1
year_bins <- seq(1947, 2016, by=2)+1
bills_over_years <- ggplot(bills, aes(x = Year)) +
  geom_histogram(breaks = year_bins, color = "white", fill = my_palette[["green"]]) +
  geom_hline(yintercept = 0, color = my_palette[["lightgray"]]) +
  xlab("Year") +
  ylab("Number of Bills") +
  scale_y_continuous(minor_breaks=seq(0,500, by=20)) +
  theme.bar
bills_over_years
ggsave(file.path(fig_dir, "A histogram of the frequency of the 10K bills over years.jpeg"), height = 2.5, width = 4)

# Fig 2
bills_llm <- read.csv(file.path(data_dir, "bills_llm.csv")) %>%
  rename(c(prompt=PromptingStrategyID, model=Model, Yhuman=Major, Yllm=MajorLLM)) %>%
  select(c(prompt, model, Yhuman, Yllm)) %>%
  mutate(model = factor(
    model, 
    levels=c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13"), 
    labels=c("GPT-3.5", "GPT-4o")
  )) %>%
  group_by(model, prompt) %>%
  summarise(accuracy = mean(Yhuman==Yllm), .groups="drop")

accuracy <- bills_llm %>%
  ggplot(aes(x=as.factor(prompt), y=accuracy, fill=model)) +
  geom_col(width=0.75, position=position_dodge()) +
  xlab("Prompt Index") +
  ylab("Accuracy") +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  scale_fill_manual(name=NULL, values=my_colors) +
  theme.bar

# save figure
ggsave(file.path(fig_dir, "Accuracy of Topic Predictions vs. Prompt.jpeg"), height = 4, width = 6)

# Create frames for the slides from the figure above
fig_color <- my_colors[as.character(sort(unique(bills_llm$model)))]

accuracy_frame1 <- accuracy + 
  scale_fill_manual(name=NULL, values=alpha(fig_color, 0)) +
  guides(fill = guide_legend(override.aes = list(fill=fig_color)))

accuracy_frame2 <- accuracy

# save figure
ggsave(file.path(slides_fig_dir, "Accuracy of Topic Predictions vs. Prompt, Frame 1.jpeg"), plot = accuracy_frame1, height = 4, width = 6)
ggsave(file.path(slides_fig_dir, "Accuracy of Topic Predictions vs. Prompt, Frame 2.jpeg"), plot = accuracy_frame2, height = 4, width = 6)


# Heat maps, code based on headlines/code/produce_figures/heatmaps.R
model_levels <- c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13")
model_labels <- c("GPT-3.5", "GPT-4o")
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
  `10`="Few-Shot: Example Set 1",
  `11`="Few-Shot: Example Set 2",
  `12`="Few-Shot: Example Set 3"
)

bills_llm <- read.csv(file.path(data_dir, "bills_llm.csv")) %>%
  rename(c(bill_id=BillID, prompt=PromptingStrategyID, model=Model, Yllm=MajorLLM)) %>%
  select(c(bill_id, prompt, model, Yllm)) %>%
  mutate(
    model = factor(model, levels=model_levels, labels=model_labels),
    prompt = factor(prompt, levels=names(prompt_labels_values), labels=prompt_labels_values),
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
}

# Iterate over models and compute the agreement_matrix
agreement_matrices <- list()
for (curr_model in unique(bills_llm$model)) {
  datasets <- bills_llm %>% 
    filter(model==curr_model)
  
  # Calculate and store agreement matrix
  agreement_df <- create_agreement_matrix(datasets)
  agreement_df$model <- curr_model
  agreement_matrices[[curr_model]] <- agreement_df
}
agreement_matrices <- bind_rows(agreement_matrices)

# Store global min and max
global_min <- min(agreement_matrices$agreement, na.rm = TRUE)
global_max <- max(agreement_matrices$agreement, na.rm = TRUE)

# Plot agreement matrix
agreement_fig <- agreement_matrices %>%
  # filter(model=="GPT-4o") %>%
  ggplot(aes(x=prompt_x, y=prompt_y, fill=agreement)) +
  geom_tile() +
  facet_grid(~ model) +
  labs(
    x = "Prompting Strategy", 
    y = "Prompting Strategy", 
    fill = "Pairwise Agreement Percent"
  ) + 
  scale_fill_viridis_c(
    option = "plasma", 
    direction = -1, 
    limits = c(global_min, global_max)
  ) +
  # Add agreement percentage with appropriate font color for clarity.
  geom_text(aes(
    label = sprintf("%.1f", agreement), 
    color = ifelse(agreement > 0.7*global_min+0.3*global_max, "white", "black")
    ), size = 2.5, show.legend = FALSE) + 
  scale_color_identity() +
  theme.heatmap +
  guides(fill = guide_colourbar(title.vjust = .8))

agreement_fig
# save figure
fig_path = file.path(fig_dir, "Pairwise Agreement by Model.jpeg")
ggsave(fig_path, plot = agreement_fig, height = 5, width = 8)
cat(sprintf("Saved %s\n", fig_path))

# Plot agreement matrix for GPT-4o only
agreement_fig_gpt4o <- agreement_matrices %>%
  filter(model=="GPT-4o") %>%
  ggplot(aes(x=prompt_x, y=prompt_y, fill=agreement)) +
  geom_tile() +
  labs(
    x = "Prompting Strategy", 
    y = "Prompting Strategy", 
    fill = "Pairwise Agreement Percent"
  ) + 
  scale_fill_viridis_c(
    option = "plasma", 
    direction = -1, 
    limits = c(global_min, global_max)
  ) +
  # Add agreement percentage with appropriate font color for clarity.
  geom_text(aes(
    label = sprintf("%.1f", agreement), 
    color = ifelse(agreement > 0.7*global_min+0.3*global_max, "white", "black")
  ), size = 2.5, show.legend = FALSE) + 
  scale_color_identity() +
  theme.heatmap +
  guides(fill = guide_colourbar(title.vjust = .8))

agreement_fig_gpt4o

# save figure
fig_path = file.path(fig_dir, "Pairwise Agreement, GPT-4o.jpeg")
ggsave(fig_path, plot = agreement_fig_gpt4o, height = 5.2, width = 5.2)
cat(sprintf("Saved %s\n", fig_path))


 # Fig 3 & 4
bills_llm <- read.csv(file.path(data_dir, "bills_llm.csv")) %>%
  rename(c(prompt=PromptingStrategyID, model=Model, Yhuman=Major, Yllm=MajorLLM)) %>%
  mutate(model = factor(
    model, 
    levels=c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13"), 
    labels=c("GPT-3.5", "GPT-4o")
  )) 
n_bills <- length(unique(bills_llm$BillID))

# Fig 3
stat <- bills_llm %>%
  group_by(model, BillID) %>%
  summarise(UniqueYllm = n_distinct(Yllm), .groups="drop") %>%
  group_by(model, UniqueYllm) %>%
  summarise(Count = n(), .groups="drop") %>%
  ungroup() %>%
  mutate(Share = Count / n_bills)

unique_llm <- stat %>% 
  ggplot(aes(x=as.factor(UniqueYllm), y=Share, fill=model)) +
  geom_col(position=position_dodge()) +
  xlab("Number of unique LLM major topic labels") +
  ylab("Share of Bills") +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.04)) +
  theme.bar

unique_llm
ggsave(file.path(fig_dir, "Histogram of unique LLM labels across all prompt modifications.jpeg"), height = 3.5, width = 4)

# Fig 4
stat <- bills_llm %>%
  filter(PromptingStrategyName == "Few-Shot") %>%
  group_by(model, BillID) %>%
  summarise(UniqueYllm = n_distinct(Yllm), .groups="drop") %>%
  group_by(model, UniqueYllm) %>%
  summarise(Count = n(), .groups="drop") %>%
  ungroup() %>%
  mutate(Share = Count / n_bills)

unique_llm_fewshot <- stat %>% 
  ggplot(aes(x=as.factor(UniqueYllm), y=Share, fill=model)) +
  geom_col(position=position_dodge()) +
  xlab("Number of unique LLM major topic labels in fewshot prompts") +
  ylab("Share of Bills") +
  scale_fill_manual(name=NULL, values=my_colors) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.04)) +
  theme.bar

unique_llm_fewshot
ggsave(file.path(fig_dir, "Histogram of unique LLM labels in few-shot prompts.jpeg"), height = 3.5, width = 4)
