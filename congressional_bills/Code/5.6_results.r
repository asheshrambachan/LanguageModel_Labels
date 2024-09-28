# Results Bills and LLM
# Sep 23, 2024

setwd("~/Documents/LanguageModel_Labels/congressional_bills/")
repo_dir = "."
data_dir = file.path(repo_dir, "Data") 
fig_dir = file.path(repo_dir, "Figures and Tables/5.5/")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Load required packages quietly and custom functions
suppressPackageStartupMessages({
  require(dplyr)
  require(ggplot2)
  require(lemon)
})
source(file.path(repo_dir, "Code/ggplot_theme.r"))

bills <- read.csv(file.path(data_dir, "bills_prediction.csv"))

# Fig 1
year_bins <- seq(1947, 2016, by=2)+1
bills_over_years <- ggplot(bills, aes(x = Year)) +
  geom_histogram(breaks = year_bins, color = "white", fill = my_palette[["green"]]) +
  geom_hline(yintercept = 0, color = my_palette[["lightgray"]]) +
  xlab("Year") +
  ylab("Number of Bills") +
  scale_y_continuous(minor_breaks=seq(0,1000, by=20)) +
  theme.bar
bills_over_years
ggsave(file.path(fig_dir, "fig01 A histogram of the frequency of the 10K bills over years.jpeg"), height = 2.5, width = 4)

# Fig 2
bills_llm_passage <- read.csv(file.path(data_dir, "bills_llm_passage.csv")) %>%
  rename(Prompt=PromptingStrategyID) %>%
  select(c(Prompt, Model, AddIntrDate, PassS, PassSLLM, PassH, PassHLLM)) %>%
  mutate(Model = factor(
    Model, 
    levels=c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13"), 
    labels=c("GPT-3.5", "GPT-4o")
  )) %>%
  group_by(Model, AddIntrDate) %>%
  summarise(
    accuracyS = mean(PassS==PassSLLM), 
    accuracyH = mean(PassH==PassHLLM), 
    .groups="drop"
  ) %>% 
  tidyr::pivot_longer(cols = c(accuracyS, accuracyH), names_to = "chamber", values_to = "accuracy") %>%
  mutate(chamber = ifelse(chamber == "accuracyS", "Pass Senate", "Pass House"))

bills_llm_passage %>%
  ggplot(aes(x=as.factor(AddIntrDate), y=accuracy, fill=Model)) +
  geom_col(position=position_dodge()) +
  facet_grid(Model ~ chamber) +
  xlab("Information Up to Intro Date Restriction in Prompt") +
  ylab("Accuracy") +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  scale_fill_manual(name="", values=my_colors) +
  theme.bar +
  guides(fill="none")

ggsave(file.path(fig_dir, "fig02 Accuracy of Bill Pass Predictions vs. Intro Date.jpeg"), height = 3.5, width = 4)

# Figure 3


Similarity <- read.csv(file.path(data_dir, "bills_llm_completion_embed.csv")) %>%
  rename(Prompt=PromptingStrategyID) %>%
  select(c(Prompt, Model, AddIntrDate, Similarity)) %>%
  mutate(Model = factor(
    Model, 
    levels=c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13"), 
    labels=c("GPT-3.5", "GPT-4o")
  )) %>%
  group_by(Model, AddIntrDate) %>%
  summarise(
    Mean = mean(Similarity),
    SE = sd(Similarity),
    .groups = "drop"
  )
  
# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)
ci_value <- matrix(Similarity$SE, ncol=1) %*% matrix(qnorm(probs) , ncol=2) + Similarity$Mean
colnames(ci_value) <- sprintf("%.1f%%", probs*100)
Similarity$LCI = ci_value[,1]
Similarity$UCI = ci_value[,2]

Similarity %>%
  ggplot(aes(x=as.factor(AddIntrDate), y=Mean, fill=Model)) +
  # geom_col(position=position_dodge()) +
  geom_point() + 
  geom_errorbar(aes(ymin=LCI, ymax=UCI), position=position_dodge(width=0.5), width=0.5, linewidth=0.3) +
  facet_grid(. ~ Model) +
  xlab("Information Up to Intro Date Restriction in Prompt") +
  ylab("Cosine Similarity") +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  scale_fill_manual(name="", values=my_colors) +
  theme.bar
  # guides(fill="none")
ggsave(file.path(fig_dir, "fig03 Accuracy of Bill Summary Completion Predictions vs. Intro Date.jpeg"), height = 3.5, width = 4)
