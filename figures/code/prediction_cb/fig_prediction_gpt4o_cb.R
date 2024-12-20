# Dec 13, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/prediction_cb")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "prediction_cb/Data/prediction_accuracy.csv")
fig_path <- file.path(fig_dir, "fig_prediction_gpt4o_cb.jpeg")
fig_width <- 9
fig_height <- 3.5

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Load and format data
data <- read.csv(data_path) %>%
  filter(
    Model=="GPT-4o"
  )

# Plot figure
fig <- data %>%
  ggplot(aes(x=as.factor(Chamber), y=Accuracy, fill=Model)) +
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
