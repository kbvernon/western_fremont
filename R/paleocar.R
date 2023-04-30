
# PaleoCAR climate reconstruction for western United States

##############################.
#     Table of Contents
# 01. Preamble
# 02. Load data
# 03. PaleoCAR models
# 04. Collect results in HUC10 watersheds
# 05. 
##############################.

# Note: for this analysis, we average the results (collapse the time dimension) 
# across the entire sequence, as we lack a tight site occupation chronology
# thus, we are getting something similar to Bocinsky's maize farming "refugia"

# 01) PREAMBLE ------------------------------------------------------------

library(here)
library(paleocar)
library(sf)
library(terra)
library(tidyverse)

# geopackage database
gpkg <- here("data", "western-fremont.gpkg")

# coordinate reference 
# EPSG:4326 (WGS84)

years_cal <- 1924:1983
years_prd <- 401:1400

# 02) LOAD DATA -----------------------------------------------------------

watersheds <- read_sf(gpkg, layer = "watersheds") |> st_transform(4326)

tree_rings <- read_rds(here("data", "western_fremont_ITRDB.Rds"))

ppt <- here("data", "rast-800m_ppt.tif") |> rast()
gdd <- here("data", "rast-800m_gdd.tif") |> rast()

# 03) PALEOCAR MODELS -----------------------------------------------------

ppt <- ppt |> 
  terra::extract(vect(watersheds), fun = mean) |> 
  select(-ID) |> 
  t()

pcar_ppt <- paleocar(
  chronologies      = itrdb,
  predictands       = ppt,
  calibration.years = years_cal,
  prediction.years  = years_prd,
  min.width         = 5,
  verbose           = TRUE,
  label             = "ppt",
  out.dir           = here("data")
)

gdd <- gdd |> 
  terra::extract(vect(watersheds), fun = mean) |> 
  select(-ID) |> 
  t()

pcar_gdd <- paleocar(
  chronologies      = itrdb,
  predictands       = gdd,
  calibration.years = years_cal,
  prediction.years  = years_prd,
  verbose           = TRUE,
  label             = "gdd",
  out.dir           = here("data")
)

# 04) COLLECT RESULTS -----------------------------------------------------

pull_prediction <- function(x){ 
  
  x |> 
    pluck("predictions") |> 
    group_by(cell) |> 
    rename("scaled_prediction" = 'Prediction (scaled)') |> 
    summarize(estimate = median(scaled_prediction, na.rm = TRUE)) |> 
    pull(estimate)
  
}

watersheds <- watersheds |> 
  mutate(
    precipitation = pull_prediction(pcar_ppt),
    gdd = pull_prediction(pcar_gdd)
  ) |> 
  st_transform(26912)

write_sf(
  watersheds,
  dsn = gpkg,
  layer = "watersheds"
)
