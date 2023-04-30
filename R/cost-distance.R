
# Site distribution for the western Fremont -- Data Wrangling
# Vernon 2022

##############################.
#     Table of Contents
# 01. Preamble
# 02. Load data
# 03. Prepare data 
# 04. Calculate cost-distance
# 05. 
##############################.

# 01) PREAMBLE ------------------------------------------------------------

# Load libraries
library(furrr)
library(here)
library(hiker)
library(sf)
library(terra)
library(tidyverse)

# geopackage database
gpkg <- here("data", "western-fremont.gpkg")

# Set a "plan" for how the code should run.
plan(multisession, workers = 4)

# load custom functions
# doing it this way to mask the functions in the global environment
sys.source(
  here("R", "fun-extractors.R"),
  envir = attach(NULL, name = "extractors")
)

sys.source(
  here("R", "fun-cost_distance.R"),
  envir = attach(NULL, name = "cost")
)

# 02) LOAD DATA -----------------------------------------------------------

dem <- rast(here("data", "rast-250m_dem.tif"))

window     <- read_sf(gpkg, layer = "window")
watersheds <- read_sf(gpkg, layer = "watersheds")
springs    <- read_sf(gpkg, layer = "springs")
streams    <- read_sf(gpkg, layer = "streams")
roads      <- read_sf(gpkg, layer = "roads")

# 03) PREPARE DATA --------------------------------------------------------

# aggregate the dem to speed up processing time
# at the scale, it shouldn't make much difference
dem <- project(dem, crs(dem), res = c(500,500))

# subset roads to interstate (I), us highway (U), and state highway (S)
roads <- roads |>
  filter(rttyp %in% c("U", "I", "S")) |>
  st_intersection(window)

# hiker only works with point locations, so sample one point every 500 meters (1/500)
# this will exclude line segments shorter than 500 meters in length
roads <- roads |>
  st_cast("LINESTRING") |>
  st_line_sample(density = 1/500) |>
  st_cast("POINT") |>
  st_as_sf() |>
  (\(x) filter(!st_is_empty(x)))()

streams <- streams |>
  st_cast("LINESTRING") |>
  st_line_sample(density = 1/500) |>
  st_cast("POINT") |>
  st_as_sf() |>
  (\(x) filter(!st_is_empty(x)))()

# 04) COST-DISTANCE -------------------------------------------------------

terrain <- hf_terrain(dem)

progressr::with_progress({
  cd_springs <- survey_parallel(terrain, springs)
  gc()
})

plan(sequential) # supposedly, this ensures that the parallel sessions get flushed
plan(multisession, workers = 4)

progressr::with_progress({
  cd_streams <- survey_parallel(terrain, streams)
  gc()
})

plan(sequential)
plan(multisession, workers = 4)

progressr::with_progress({
  cd_roads <- survey_parallel(terrain, roads)
  gc()
})

plan(sequential)

writeRaster(
  cd_springs,
  here("data", "rast-500m_cd_springs.tif")
)

writeRaster(
  cd_streams,
  here("data", "rast-500m_cd_streams.tif")
)

writeRaster(
  cd_roads,
  here("data", "rast-500m_cd_roads.tif")
)

watersheds <- watersheds |>
  mutate(
    springs = extract_value(watersheds, cd_springs, mean), 
    streams = extract_value(watersheds, cd_streams, mean),
    roads   = extract_value(watersheds, cd_roads,   mean)
  ) |>
  mutate(
    across(c(springs, streams, roads), ~ .x/3600)
  )

write_sf(
  watersheds,
  dsn = gpkg,
  layer = "watersheds"
)
