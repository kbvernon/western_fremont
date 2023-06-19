
# Elevation drives everything

##############################.
#     Table of Contents
# 01. Preamble
# 02. Load data
# 03. PaleoCAR models
# 04. Collect results in HUC10 watersheds
# 05. 
##############################.

# 01) PREAMBLE ------------------------------------------------------------

library(broom)
library(geomtextpath)
library(here)
library(terra)
library(tidyverse)

# 02) DATA ----------------------------------------------------------------

elevation <- rast(here("data", "rast-250m_dem.tif"))
streams <- rast(here("data", "rast-500m_cd_streams.tif"))
streams <- streams/3600 # convert to hours

precipitation <- rast(here("data", "rast-800m_ppt.tif")) |> 
  project("EPSG:26912") |> 
  mean()

gdd <- rast(here("data", "rast-800m_gdd.tif")) |> 
  project("EPSG:26912") |> 
  mean()

elevation <- resample(elevation, gdd)
streams <- resample(streams, gdd)

rstack <- c(elevation, streams, precipitation, gdd)
names(rstack) <- c("elevation", "streams", "precipitation", "gdd")

# 03) OLS -----------------------------------------------------------------

training_data <- spatSample(
  rstack,
  size = 10000,
  method = "regular",
  na.rm = TRUE
) |> 
  na.omit() |> 
  arrange(elevation)

fit_lm <- function(variable, .data) {
  
  .f <- as.formula(paste0(variable, "~elevation"))
  
  .m <- lm(.f, .data)
  
  broom::tidy(.m) |> 
    rename(
      "x" = term,
      "t.statistic" = statistic
    ) |> 
    slice(2) |> 
    mutate(
      "y" = variable,
      "r2" = summary(.m)$r.squared
    ) |> 
    select(y, x, everything())
  
}

q <- lapply(
  c("gdd", "precipitation", "streams"), 
  fit_lm, 
  .data = training_data
) |> bind_rows()

bob <- global(c(gdd, precipitation, streams), mean, na.rm = TRUE)[, 1, drop = TRUE]

q <- mutate(q, "y.mean" = round(bob, 2))

write_csv(q, here("data", "elevation-everything.csv"))

# 03) SMOOTH PLOTS --------------------------------------------------------

plot_data <- training_data |> 
  mutate(across(-elevation, scale)) |> 
  pivot_longer(
    -elevation, 
    names_to = "variable", 
    values_to = "value"
  ) |> 
  mutate(
    variable = case_when(
      variable == "precipitation" ~ "Precipitation (mm)",
      variable == "gdd" ~ "Maize GDD (°C)",
      variable == "streams" ~ "Streams (hours)",
      TRUE ~ variable
    )
  )

ggplot(
  plot_data, 
  aes(elevation, value, group = variable, color = variable)
) +
  geom_textsmooth(
    aes(label = variable),
    method = "lm", 
    se = FALSE,
    linewidth = 1,
    lineend='round',
    size = 4,
    hjust = 0.9
  ) +
  scale_color_manual(
    name = NULL,
    values = c("#4F3824", "#D1603D", "#DDB967", "#848FA5")[c(1,2,4)]
  ) +
  xlab("Elevation (m)") +
  ylab("z-score") +
  theme_bw(11) +
  theme(
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    panel.grid.minor.y = element_blank(),
    plot.margin = margin(5,15,5,5)
  )

ggsave(
  here("figures", "elevation-everything.png"),
  width = 4,
  height = 3,
  dpi = 300
)

ggsave(
  here("figures", "elevation-everything.jpg"),
  width = 4,
  height = 3,
  dpi = 600
)
