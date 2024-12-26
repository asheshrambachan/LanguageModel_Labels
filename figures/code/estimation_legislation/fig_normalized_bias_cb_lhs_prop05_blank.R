# Create a blank version of fig_normalized_bias_cb_lhs_prop05.R
# Dec 10, 2024

# Load figure
source("./figures/code/estimation_legislation/fig_normalized_bias_cb_lhs_prop05.R")

# Figure path
blank_fig_path <- file.path(fig_dir, "fig_normalized_bias_cb_lhs_prop05_blank.jpeg")

# Plot blank figure
blank_fig <- fig + 
  scale_color_manual(values=alpha(my_colors, 0)) + 
  scale_fill_manual(values=alpha(my_colors, 0)) 

# Add legend aesthetics
legend_aes <- ggplot_build(fig)$data[[1]] %>% 
  select(c(colour, fill)) %>% 
  unique()

blank_fig <- blank_fig +
  guides(color = guide_legend(override.aes = legend_aes))

# Save figures
ggsave(blank_fig_path, plot = blank_fig, height = fig_height, width = fig_width)
cat(sprintf("Saved %s\n", fig_path))