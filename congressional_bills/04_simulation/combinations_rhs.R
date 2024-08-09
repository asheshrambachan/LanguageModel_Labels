# List of combinations
combinations = expand.grid(
  train_proportion = c(0.05, 0.1, 0.25, 0.5), # 10%train 90%test, ...  
  prompt = 1:12,
  model = c("gpt-3.5-turbo-0125", "gpt-4o"),
  variable = c("Senate", "Democrat", "DW1"), 
  stringsAsFactors = FALSE) %>%
  mutate(
    combination_id = 1:n(), # id is used as seed 
    N = 1000, 
    B=1000, 
    n_samples=5000
  ) %>% 
  relocate(combination_id)

repo_dir = "~/Documents/LanguageModel_Labels/congressional_bills"
simulation_dir = file.path(repo_dir, "04_simulation")
combinations_path = file.path(simulation_dir, "rhs_combinations.csv")
write.csv(combinations, combinations_path, row.names = FALSE)
