#' Recode Topics to Predefined List with "Other" for Non-Matching Topics
#'
#' This function recodes a vector of topics using a provided list of topics and converts non-included topics to "Other".
#' @param x A vector of topics to be recoded.
#' @param topics A vector of predefined topics.
#' @return A recoded factor vector with non-matching topics labeled as "Other".
#' @export
recode_topics <- function(x, topics){
  x_recoded <- addNA(factor(x, levels=topics))  # Recode factor levels, including NA
  n <- nlevels(x_recoded)
  if (is.na(levels(x_recoded)[n]))
    levels(x_recoded)[n] <- "Other" # Label NA levels as "Other"
  return(x_recoded)
}
