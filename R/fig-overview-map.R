
# Create a regional overview map of the project area

####################.
#    OUTLINE
# 1) R Preamble
# 2) features
# 3) basemap
# 4) main map
# 5) inset map
# 6) site density map
# 7) save
####################.

# R preamble --------------------------------------------------------------

library(ggfx)
library(ggspatial)
library(here)
library(patchwork)
library(sf)
library(tidyverse)
library(tigris)
library(viridis)

gpkg <- here("data", "western-fremont.gpkg")

# load custom functions
# doing it this way to mask the functions in the global environment
sys.source(
  here("R", "fun-get_basemap.R"),
  envir = attach(NULL, name = "basemap")
)

# features ----------------------------------------------------------------

state_names <- c(
  "Idaho", "Wyoming", "Colorado", "New Mexico", "Arizona", "Nevada", "Utah"
)

states <- tigris::states() |> 
  rename_with(tolower) |> 
  filter(name %in% state_names) |> 
  select(name, stusps) |>
  st_transform(26912)

utah <- states |> filter(name == "Utah")

window <- read_sf(gpkg, "window")

roads <- read_sf(gpkg, "roads")

roads <- st_intersection(
  roads, 
  st_union(utah, window)
)

watersheds <- read_sf(gpkg, "watersheds")

# basemap -----------------------------------------------------------------

bb8 <- st_union(window, utah) |> st_bbox()

dy <- bb8[["ymax"]] - bb8[["ymin"]]
dx <- bb8[["xmax"]] - bb8[["xmin"]]

basemap <- get_basemap(
  bb8, 
  map = "imagery",
  size = c(9000, 9000*(dy/dx)),
  imageSR = 26912
)

# main map ----------------------------------------------------------------

bob <- ggplot() +
  as_reference(
    geom_sf(
      data = utah,
      color = "transparent",
      fill = alpha("white", 0.3)
    ),
    id = "utah-mask"
  ) +
  with_mask(
    annotation_raster(
      basemap,
      bb8[["xmin"]], bb8[["xmax"]],
      bb8[["ymin"]], bb8[["ymax"]]
    ),
    mask = ch_alpha("utah-mask")
  ) +
  geom_sf(
    data = utah, 
    fill = "transparent"
  ) +
  as_reference(
    geom_sf(
      data = window,
      color = "transparent",
      fill = "white"
    ),
    id = "window-mask"
  ) +
  with_mask(
    annotation_raster(
      basemap,
      bb8[["xmin"]], bb8[["xmax"]],
      bb8[["ymin"]], bb8[["ymax"]]
    ),
    mask = ch_alpha("window-mask")
  ) +
  geom_sf(
    data = window, 
    fill = "transparent", 
    color = "#4E2B04",
    linewidth = 0.2
  ) +
  annotation_scale(
    aes(location = "bl"),
    pad_x = unit(1.3, "cm"),
    pad_y = unit(0.7, "cm"),
    height = unit(0.2, "cm")
  ) + 
  annotation_north_arrow(
    aes(location = "br"),
    pad_x = unit(0.7, "cm"),
    pad_y = unit(0.7, "cm"),
    width = unit(0.55, "cm"),
    height = unit(1, "cm")
  ) +
  theme_void()

# inset map ---------------------------------------------------------------

wst_cntr <- states |> st_union() |> st_centroid()

flerp <- states

st_geometry(flerp) <- (st_geometry(states)-wst_cntr) * 0.085 + wst_cntr + c(34000, 240000)

st_crs(flerp) <- 26912

state_labels <- 
  flerp |> 
  st_centroid() |> 
  st_coordinates() |> 
  as_tibble() |> 
  rename_with(tolower) |> 
  mutate(
    state = states$stusps,
    color = if_else(state == "UT", "white", "black"),
    y     = if_else(state == "ID", y - 0.75, y)
  )

bob <- bob +
  geom_sf(
    data = flerp,
    fill = "gray98",
    color = "gray45",
    size = 0.1
  ) +
  geom_sf(
    data = flerp |> filter(name == "Utah"),
    fill = "gray10",
    color = "black"
  ) +
  geom_text(
    data = state_labels,
    aes(x, y, label = state, color = color),
    size = 2
  ) +
  scale_color_manual(
    values = c("black","white"),
    guide = "none"
  ) +
  theme_void()

# site density ------------------------------------------------------------

max_density_obs <- with(watersheds, max(sites/area))

site_density <- ggplot() +
  geom_sf(
    data = utah,
    fill = "gray95"
  ) +
  geom_sf(
    data = watersheds, 
    aes(fill = (sites/area)/max_density_obs),
    color = "gray90", 
    linewidth = 0.1
  ) +
  scale_fill_viridis(
    name = "Relative\nSite Density",
    option = "mako",
    limits = c(0, 1)
  ) +
  theme_void() +
  theme(
    legend.background = element_rect(fill = "gray95", color = "transparent"),
    legend.justification = c("left", "bottom"),
    legend.position = c(0.62, 0.17)
  )

# Save --------------------------------------------------------------------

everything <- bob + site_density

# ggview::ggview(
#   everything,
#   device = "png",
#   width = 7,
#   height = 7 * (dy/(2*dx)),
#   dpi = 300
# )

ggsave(
  plot = everything,
  filename = here("figures", "overview.jpg"),
  width = 5.75,
  height = 5.75 * (dy/(2*dx)),
  dpi = 600
)
