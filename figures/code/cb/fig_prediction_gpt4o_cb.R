# Dec 13, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/cb")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "cb_prediction/Data/bills_llm_passage.csv")
fig_path <- file.path(fig_dir, "fig_prediction_gpt4o_cb.jpeg")
fig_width <- 9
fig_height <- 3.5

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
prompt_labels_levels <- c(
  "False"="Base prompt", 
  "True"="Prompt with date restriction"
)
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5", 
  "gpt-4o-2024-05-13"="GPT-4o"
)

# Load and format data
data <- read.csv(data_path) %>%
  mutate(
    Model = recode_factor(Model, !!!model_labels_levels),
    Prompt = recode_factor(AddIntrDate, !!!prompt_labels_levels)
  ) %>%
  group_by(Model, Prompt) %>%
  summarize(
    `Accuracy.Pass Senate` = mean(PassS==PassSLLM),
    `TPR.Pass Senate` = sum(PassS==1 & PassSLLM==1) / sum(PassS==1),
    `FPR.Pass Senate` = sum(PassS==0 & PassSLLM==1) / sum(PassS==0),
    `Accuracy.Pass House` = mean(PassH==PassHLLM),
    `TPR.Pass House` = sum(PassH==1 & PassHLLM==1) / sum(PassH==1),
    `FPR.Pass House` = sum(PassH==0 & PassHLLM==1) / sum(PassH==0),
    .groups="drop"
  ) %>%
  tidyr::pivot_longer(
    -c(Model, Prompt),
    names_to = c(".value", "PredictedOutcome"),
    names_sep = "\\."
  ) %>%
  relocate(PredictedOutcome, 1) %>%
  arrange(PredictedOutcome, Model, Prompt) %>%
  filter(Model=="GPT-4o")

# Plot figure
fig <- data %>%
  ggplot(aes(x=as.factor(PredictedOutcome), y=Accuracy, fill=Model)) +
  geom_col(width=0.5) +
  facet_grid(. ~ Prompt)

# Add theme and aesthetics
fig <- fig +
  labs(
    x = "Predicted Outcome",
    y = "Prediction Accuracy"
  ) +
  scale_y_continuous(minor_breaks=seq(0, 1, by=0.05), limits=c(0,1)) +
  scale_fill_manual(name="", values=my_colors) +
  theme.bar +
  guides(fill="none", color="none") +
  theme(panel.spacing = unit(0.5, "cm", data = NULL))

# Save figure
ggsave(fig_path, plot = fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))
