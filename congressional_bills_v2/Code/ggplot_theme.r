# # 1. download ttf file from https://www.fontsquirrel.com/fonts/computer-modern
# # 2. install on mac 
# # 3. Run once in R: 
# font_import(paths="~/Library/Fonts/", pattern="cmun*")
# # names(pdfFonts()) # uncomment to get list of fonts
loadfonts(quiet=T)

my_palette <- c("red"="#F85427", "blue"="#277BB6", "green"="#97BD59", "yellow"="#FFD166", "black"="#262626", "gray"="#605856", "lightgray"="#EBEBEB")
my_colors <- c(
  "GPT-3.5" =  my_palette[["green"]],
  "GPT-4o" = my_palette[["blue"]],
  "Human" = my_palette[["red"]], 
  
  "LLM" = my_palette[["green"]], 
  "Human Validation" = my_palette[["red"]],
  "Debiased" = my_palette[["gray"]]
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
    text=element_text(size=12, family="CMU Sans Serif"),
    legend.title=element_text(size=10, family="CMU Sans Serif Bold"),
    plot.title=element_text(size=14, family="CMU Sans Serif Bold"),
    plot.subtitle=element_text(size=12, family="CMU Sans Serif")
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
    text=element_text(size=12, family="CMU Sans Serif"),
    legend.title=element_text(size=10, family="CMU Sans Serif Bold"),
    plot.title=element_text(size=14, family="CMU Sans Serif Bold"),
    plot.subtitle=element_text(size=12, family="CMU Sans Serif")
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
    text=element_text(size=12, family="CMU Sans Serif"),
    legend.title=element_text(size=10, family="CMU Sans Serif Bold"),
    plot.title=element_text(size=14, family="CMU Sans Serif Bold"),
    plot.subtitle=element_text(size=12, family="CMU Sans Serif")
  )