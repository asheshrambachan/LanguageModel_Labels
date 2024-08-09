# create list of combinations

## Run 1
combinations_run1 = expand.grid(
  train_proportion = c(0.1, 0.25, 0.5), # 10%train 90%test, ...  
  prompt = 1:12,
  model = c("gpt-3.5-turbo-0125", "gpt-4o"),
  variable = c("Senate", "Democrat", "DW1"), 
  major_topic = c(3, 14, 15, 19, 20), # these are the most common major topics based on Major/Yhuman column (not MajorLLM/Yllm)
  stringsAsFactors = FALSE) %>%
  mutate(
    id = 1:n(), # id is used as seed 
    N = 1000, 
    B=1000, 
    n_samples=5000
  ) %>% 
  relocate(id)

repo_dir = "~/Documents/LanguageModel_Labels/congressional_bills"
simulation_dir = file.path(repo_dir, "04_simulation")
combinations_run1_path = file.path(simulation_dir, "lhs_combinations_run1.csv")
write.csv(combinations_run1, combinations_run1_path, row.names = FALSE)

## Run 2
# combinations_run1 = read.csv(combinations_run1_path)
last_id_run1 = max(combinations_run1$id)
combinations_run2 = expand.grid(
  train_proportion = 0.05,
  prompt = 1:12,
  model = c("gpt-3.5-turbo-0125", "gpt-4o"),
  variable = c("Senate", "Democrat", "DW1"), 
  major_topic = c(3, 14, 15, 19, 20), # these are the most common major topics based on Major/Yhuman column (not MajorLLM/Yllm)
  stringsAsFactors = FALSE) %>%
  mutate(
    id = (1:n())+last_id_run1, # id is used as seed 
    N = 1000, 
    B=1000, 
    n_samples=5000
  ) %>% 
  relocate(id)

combinations_run2_path = file.path(simulation_dir, "lhs_combinations_run2.csv")
write.csv(combinations_run2, combinations_run2_path, row.names = FALSE)

## Merge
combinations = bind_rows(combinations_run1, combinations_run2)
combinations_path = file.path(simulation_dir, "lhs_combinations.csv")
write.csv(combinations, combinations_path, row.names = FALSE)

