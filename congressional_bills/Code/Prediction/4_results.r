# Results Bills and LLM
# Sep 23, 2024

repo_dir = "~/Documents/LanguageModel_Labels/congressional_bills"
data_dir = file.path(repo_dir, "Data/Prediction") 
fig_dir = file.path(repo_dir, "Figures/Prediction")
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
year_bins <- seq(min(bills$Year), max(bills$Year), by=2)+1
bills_over_years <- ggplot(bills, aes(x = Year)) +
  geom_histogram(breaks = year_bins, color = "white", fill = my_palette[["green"]]) +
  geom_hline(yintercept = 0, color = my_palette[["lightgray"]]) +
  xlab("Year") +
  ylab("Number of Bills") +
  scale_y_continuous(minor_breaks=seq(0,1000, by=20)) +
  theme.bar
bills_over_years

fig_path = file.path(fig_dir, "A histogram of the frequency of the 10K bills over years.jpeg")
ggsave(fig_path, plot = bills_over_years, height = 2.5, width = 4)

# Fig 2

data_fig02 <- read.csv(file.path(data_dir, "bills_llm_passage.csv")) %>%
  rename(Prompt=PromptingStrategyID) %>%
  mutate(
    Model = factor(Model, levels=c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13"), labels=c("GPT-3.5", "GPT-4o")),
    accuracyS = as.integer(PassS==PassSLLM),
    accuracyH = as.integer(PassH==PassHLLM),
    temp = as.integer(PassS==PassH),
    AddIntrDate = factor(
      AddIntrDate,
      levels=c("False", "True"),
      labels=c("Without Date Restriction", "With Date Restriction")
    ) 
  ) 

temp <- data_fig02 %>% filter(is.na(PassHLLM) | is.na(PassSLLM))
print(temp)

# CI
alpha <- 0.10
probs <- c(alpha/2, 1-alpha/2)
data_fig02 <- data_fig02 %>%
  filter(!is.na(PassHLLM) & !is.na(PassSLLM)) %>%
  select(c(Prompt, Model, AddIntrDate, accuracyS, accuracyH)) %>%
  tidyr::pivot_longer(cols = c(accuracyS, accuracyH), names_to = "Chamber", values_to = "Accuracy") %>%
  mutate(Chamber = ifelse(Chamber == "accuracyS", "Pass Senate", "Pass House")) %>%
  group_by(Chamber, Model, AddIntrDate) %>%
  summarise(
    Mean = mean(Accuracy, na.rm=TRUE),
    SE = sd(Accuracy, na.rm=TRUE),
    .groups="drop"
  ) 
# ci_value <- matrix(data_fig02$SE, ncol=1) %*% matrix(qnorm(probs) , ncol=2) + data_fig02$Mean
# colnames(ci_value) <- sprintf("%.1f%%", probs*100)
# data_fig02$LCI = ci_value[,1]
# data_fig02$UCI = ci_value[,2]

data_fig02 %>%
  ggplot(aes(x=as.factor(AddIntrDate), y=Mean, fill=Model)) +
  geom_col(position=position_dodge()) +
  # geom_point() + 
  # # geom_errorbar(aes(ymin=LCI, ymax=UCI), width=0.5, linewidth=0.3) +
  facet_grid(. ~ Chamber) +
  xlab("Prompt") +
  ylab("Accuracy of\nBill Passage Predictions") +
  scale_y_continuous(minor_breaks=seq(0, 1, by=0.05), limits=c(0,1)) +
  scale_fill_manual(name="", values=my_colors) +
  theme.bar
ggsave(file.path(fig_dir, "Accuracy of Bill Passage Predictions.jpeg"), height = 3.5, width = 6)

# Figure 3

data_fig03 <- read.csv(file.path(data_dir, "bills_llm_completion_similarity.csv")) %>%
  rename(Prompt=PromptingStrategyID) %>%
  select(c(Prompt, Model, AddIntrDate, CosineSimilarity, EuclideanDistance)) %>%
  mutate(
    Model = factor(
      Model, 
      levels=c("gpt-3.5-turbo-0125", "gpt-4o-2024-05-13"), 
      labels=c("GPT-3.5", "GPT-4o")
    ),
    AddIntrDate = factor(
      AddIntrDate,
      levels=c("False", "True"),
      labels=c("Without Date Restriction", "With Date Restriction")
    )
  ) %>%
  tidyr::pivot_longer(cols = c(CosineSimilarity, EuclideanDistance), names_to = "Measure", values_to = "Distance") %>%
  mutate(Measure = ifelse(Measure == "CosineSimilarity", "Cosine Similarity", "Euclidean Distance")) %>%
  group_by(Measure, Model, AddIntrDate) %>%
  summarise(
    Mean = mean(Distance),
    SE = sd(Distance),
    .groups = "drop"
  )

# # CI
# alpha <- 0.10
# probs <- c(alpha/2, 1-alpha/2)
# ci_value <- matrix(data_fig03$SE, ncol=1) %*% matrix(qnorm(probs) , ncol=2) + data_fig03$Mean
# colnames(ci_value) <- sprintf("%.1f%%", probs*100)
# data_fig03$LCI = ci_value[,1]
# data_fig03$UCI = ci_value[,2]

data_fig03 %>%
  ggplot(aes(x=as.factor(AddIntrDate), y=Mean, fill=Model)) +
  geom_col(position=position_dodge()) +
  facet_grid(. ~ Measure) +
  xlab("Prompt") +
  ylab("Distance between\nTrue vs. LLM-Completed Bill") +
  scale_y_continuous(minor_breaks=seq(0, 1, by=0.05), limits=c(0,1)) +
  scale_fill_manual(name="", values=my_colors) +
  theme.bar

  # guides(fill="none")
ggsave(file.path(fig_dir, "Distance between True vs. LLM Bill.jpeg"), height = 3.5, width = 6)
