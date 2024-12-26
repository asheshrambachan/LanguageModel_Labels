# Create a blank version of fig_llm_accuracy_cb.R
# Dec 10, 2024

# Load figure
source("./figures/code/estimation_legislation/fig_llm_accuracy_cb.R")

# Figure path
blank_fig_path <- file.path(fig_dir, "fig_llm_accuracy_cb_blank.jpeg")

# Plot blank figure
blank_fig <- fig + 
  scale_fill_manual(values=alpha(my_colors, 0)) 

# Add legend aesthetics
blank_fig <- blank_fig +
  guides(fill = guide_legend(override.aes = list(alpha=1)))

# Save figures
ggsave(blank_fig_path, plot = blank_fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))
