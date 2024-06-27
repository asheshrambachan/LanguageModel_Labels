library(dplyr)
library(tidyr)
library(ggplot2)
library(stargazer)

balanced = TRUE
zeroshot = FALSE

filename = ifelse(balanced, "balanced", "imbalanced")
prompt_type = ifelse(zeroshot, "q_gpt3_0shot", "q_gpt3_5shot")
data = read.csv(paste("./data/original_", filename, "_data.csv", sep = ""))

data$senate = ifelse(data$senate == "True", 1, 0)
data$label = ifelse(data$label == "True", 1, 0)
data$democrat = ifelse(data$democrat == "True", 1, 0)
data$Postal = as.factor(data$Postal)
data[[prompt_type]] = ifelse(data[[prompt_type]] == "True", 1, 0)

# f* models for balanced data
chamber <- lm(label ~ senate, data = data)
party <- lm(label ~ democrat, data = data)
score <- lm(label ~ dw1, data = data)
dist <- lm(label ~ dist_macro, data = data)
state <- lm(label ~ Postal, data = data)

# f_hat models for balanced data with 0shot labels
chamber_llm <- lm(as.formula(paste(prompt_type, "~ senate")), data = data)
party_llm <- lm(as.formula(paste(prompt_type, "~ democrat")), data = data)
score_llm <- lm(as.formula(paste(prompt_type, "~ dw1")), data = data)
dist_llm <- lm(as.formula(paste(prompt_type, "~ dist_macro")), data = data)
state_llm <- lm(as.formula(paste(prompt_type, "~ Postal")), data = data)

# (f* - f_hat) models for balanced data with 0shot labels
chamber_error <- lm(as.formula(paste("label -", prompt_type, "~ senate")), data = data)
chamber_b0 <- summary(chamber_error)$coefficients[1, "Estimate"]
chamber_b1 <- summary(chamber_error)$coefficients[2, "Estimate"]

party_error <- lm(as.formula(paste("label -", prompt_type, "~ democrat")), data = data)
party_b0 <- summary(party_error)$coefficients[1, "Estimate"]
party_b1 <- summary(party_error)$coefficients[2, "Estimate"]

score_error <- lm(as.formula(paste("label -", prompt_type,"~ dw1")), data = data)
score_b0 <- summary(score_error)$coefficients[1, "Estimate"]
score_b1 <- summary(score_error)$coefficients[2, "Estimate"]

dist_error <- lm(as.formula(paste("label -", prompt_type, "~ dist_macro")), data = data)
dist_b0 <- summary(dist_error)$coefficients[1, "Estimate"]
dist_b1 <- summary(dist_error)$coefficients[2, "Estimate"]

state_error <- lm(as.formula(paste("label -", prompt_type, "~ Postal")), data = data)
state_b0 <- summary(state_error)$coefficients[1, "Estimate"]
state_b1 <- summary(state_error)$coefficients

# create unbiased LLM labels
data$f_prime_chamber = data[[prompt_type]] + (chamber_b0 + data$senate * chamber_b1)
data$f_prime_party = data[[prompt_type]] + (party_b0 + data$democrat * party_b1)
data$f_prime_score = data[[prompt_type]] + (score_b0 + data$dw1 * score_b1)
data$f_prime_dist = data[[prompt_type]] + (dist_b0 + data$dist_macro * dist_b1)
data$f_prime_state = data[[prompt_type]] + (state_b0)
postal_dummies <- data.frame(model.matrix(~ Postal - 1, data = data))
for (i in 2:ncol(postal_dummies)) {
  col_name <- colnames(postal_dummies)[i]
  col <- postal_dummies[[col_name]]
  coefficient <- state_b1[col_name, "Estimate"]
  intercept <- state_b0
  data$f_prime_state <- data$f_prime_state + col * coefficient 
}

# f_prime (unbiased f_hat) models for balanced data with 0shot labels
chamber_unbiased <- lm(f_prime_chamber ~ senate, data = data)
party_unbiased <- lm(f_prime_party ~ democrat, data = data)
score_unbiased <- lm(f_prime_score ~ dw1, data = data)
dist_unbiased <- lm(f_prime_dist ~ dist_macro, data = data)
state_unbiased <- lm(f_prime_state ~ Postal, data = data)


stargazer(chamber, chamber_llm, chamber_error, chamber_unbiased)
stargazer(party, party_llm, party_error, party_unbiased)
stargazer(score, score_llm, score_error, score_unbiased)
stargazer(dist, dist_llm, dist_error, dist_unbiased)
stargazer(state, state_llm, state_error, state_unbiased)


