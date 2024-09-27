
font_family <- "Helvetica"
if ("extrafont" %in% rownames(installed.packages())){
  # 1. download ttf file from https://www.fontsquirrel.com/fonts/computer-modern
  # 2. install ttf files via GUI on mac
  extrafont::font_import(paths="~/Library/Fonts/", pattern="cmuns*.ttf", prompt=FALSE)
  extrafont::loadfonts(quiet=T)
  if ("CMU Sans Serif" %in% names(pdfFonts()))
    font_family <- "CMU Sans Serif"
}

my_palette <- c(
  "red"="#F85427", 
  "blue"="#277BB6", 
  "green"="#97BD59", 
  "yellow"="#FFD166", 
  "black"="#262626", 
  "gray"="#605856", 
  "lightgray"="#EBEBEB"
)

my_colors <- c(
  "GPT-4o-mini" =  my_palette[["red"]],
  "GPT-3.5" = my_palette[["green"]],
  "GPT-4o" = my_palette[["blue"]]
)

my_shapes <- c(
  "GPT-3.5" =  15,
  "GPT-4o-mini" = 16,
  "GPT-4o" = 17
)

theme.point <- theme_bw() + 
  theme(
    panel.grid.major.x=element_blank(), 
    panel.grid.minor.x=element_blank(), 
    panel.grid.major.y=element_line(linewidth=0.2),
    panel.grid.minor.y=element_blank(),
    legend.position="top", 
    axis.text=element_text(size=7),
    axis.ticks=element_line(linewidth=0.3),
    axis.text.x=element_blank(),
    axis.ticks.x=element_blank(),
    text=element_text(size=12, family=font_family),
    plot.subtitle=element_text(size=12, family=font_family)
  )

theme.bar <- theme_bw() + 
  theme(
    panel.grid.major.x=element_blank(), 
    panel.grid.minor.x=element_blank(), 
    panel.grid.major.y=element_line(linewidth=0.3),
    panel.grid.minor.y=element_line(linewidth=0.1),
    legend.position="top", 
    axis.text=element_text(size=7),
    axis.ticks=element_line(linewidth=0.3),
    text=element_text(size=12, family=font_family),
    plot.subtitle=element_text(size=12, family=font_family)
  )

theme.mse <- theme_bw() + 
  theme(
    panel.grid.major.x=element_line(linewidth=0.3), 
    panel.grid.minor.x=element_line(linewidth=0.1), 
    panel.grid.major.y=element_line(linewidth=0.3),
    panel.grid.minor.y=element_line(linewidth=0.1),
    legend.position="top", 
    axis.text=element_text(size=7),
    axis.ticks=element_line(linewidth=0.3),
    text=element_text(size=12, family=font_family),
    plot.subtitle=element_text(size=12, family=font_family)
  )

theme.heatmap <- theme_bw() +
  theme(
    panel.border = element_blank(),       
    panel.background = element_blank(),   
    panel.grid.major = element_blank(), 
    panel.grid.minor = element_blank(),   
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "top",
    plot.title = element_text(hjust = 0.5),
    axis.text = element_text(size = 7),
    axis.ticks = element_line(linewidth = 0.3),
    text = element_text(size = 12, family = font_family),
    plot.subtitle = element_text(size = 12, family = font_family, hjust = 0.5)
  )


