# Results Bills and LLM
# Sep 23, 2024

repo_dir = "/Users/haya1/Documents/LanguageModel_Labels/congressional_bills"
data_dir = file.path(repo_dir, "Data") 
fig_dir = file.path(repo_dir, "Figures and Tables/4.2_bills_llm_plots/")
dir.create(fig_dir, showWarnings=FALSE, recursive = TRUE)

# Load required packages quietly and custom functions
suppressPackageStartupMessages({
  require(dplyr)
  require(ggplot2)
  require(lemon)
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
ggsave(file.path(fig_dir, "fig01_bills A histogram of the frequency of the 10K bills over years.jpeg"), height = 2.5, width = 4)

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
  geom_col(position=position_dodge()) +
  xlab("Prompt Index") +
  ylab("Accuracy") +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.05), limits=c(0,1)) +
  scale_fill_manual(name="", values=my_colors) +
  theme.bar

accuracy
ggsave(file.path(fig_dir, "fig02_accuracy Accuracy of Topic Predictions vs. Prompt.jpeg"), height = 3.5, width = 4)

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
  scale_fill_manual(name="", values=my_colors) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.04)) +
  theme.bar

unique_llm
ggsave(file.path(fig_dir, "fig03_unique_llm Histogram of unique LLM labels across all prompt modifications.jpeg"), height = 3.5, width = 4)

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
  scale_fill_manual(name="", values=my_colors) +
  scale_y_continuous(minor_breaks=seq(0,1, by=0.04)) +
  theme.bar

unique_llm_fewshot
ggsave(file.path(fig_dir, "fig04_unique_llm_fewshot Histogram of unique LLM labels in few-shot prompts.jpeg"), height = 3.5, width = 4)
