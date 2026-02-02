# Figure: Accuracy of large language model labels of bill topic across model and prompt variation.
# Dec 10, 2024

# Removing all objects
rm(list = ls())

# Setup directories
repo_dir <- "~/Documents/LanguageModel_Labels"
fig_dir <- file.path(repo_dir, "figures/output/estimation_legislation")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Data and figure paths
data_path <- file.path(repo_dir, "estimation_legislation/data/bills_llm.csv")
fig_path <- file.path(fig_dir, "fig_llm_accuracy_cb.jpeg")
fig_pdf_path <- file.path(fig_dir, "fig_llm_accuracy_cb.pdf")
fig_width <- 9
fig_height <- 4.5

# Load packages and ggplot themes
require(dplyr, warn.conflicts = FALSE)
require(ggplot2, warn.conflicts = FALSE)
source(file.path(repo_dir, "figures/code/ggplot_theme.r"))

# Factor labels and levels
model_labels_levels <- c(
  "gpt-3.5-turbo-0125"="GPT-3.5-Turbo", 
  "gpt-4o-2024-05-13"="GPT-4o",
  "gpt-5-mini"="GPT-5-Mini",
  "gpt-5-nano"="GPT-5-Nano"
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
  rename(c(prompt=PromptingStrategyID, model=Model, Yhuman=Major, Yllm=MajorLLM)) %>%
  mutate(
    model = recode_factor(model, !!!model_labels_levels),
    prompt = recode_factor(prompt, !!!prompt_labels_values)
  ) %>%
  group_by(model, prompt) %>%
  summarise(
    accuracy = mean(Yhuman==Yllm), 
    .groups="drop"
  )

# Plot figure
fig <- data %>%
  ggplot(aes(x=prompt, y=accuracy, fill=model)) +
  geom_col(width=0.5, position=position_dodge()) 

# Add theme and aesthetics
fig <- fig + 
  labs(
    x = "Prompt",
    y = "Accuracy",
    fill = NULL
  ) +
  scale_fill_manual(values=my_colors) +
  scale_y_continuous(minor_breaks=seq(0,1,by=0.05), limits=c(0,1)) +
  scale_x_discrete(labels = function(x) stringr::str_wrap(x, width = 11, whitespace_only=F)) +
  theme.bar # + 
  # theme(axis.text=element_text(size=8.5))

# Save figure
ggsave(fig_path, height = fig_height, width = fig_width, dpi=300)
cat(sprintf("Saved %s\n", fig_path))
ggsave(fig_pdf_path, height = fig_height, width = fig_width, dpi=300)
cat(sprintf("Saved %s\n", fig_pdf_path))
