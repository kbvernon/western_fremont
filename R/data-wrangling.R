
# Site distribution for the western Fremont -- Data Wrangling

# Note:
# 1- Sensitive site data cannot be shared directly, so you'll need to get it
#    from NV and UT SHPOs, or get their permission to get it from us.
#    You can't run this code without it!

# 01) PREAMBLE ------------------------------------------------------------

# Load libraries
library(FedData)
library(here)
library(sf)
library(spData)
library(terra)
library(tidyverse)
library(tigris)

# geopackage database
gpkg <- here("data", "western-fremont.gpkg")

# coordinate reference 
# EPSG:26912

# load custom functions
# doing it this way to mask the functions in the global environment
sys.source(
  here("R", "fun-download_features.R"), # requires httr and jsonlite
  envir = attach(NULL, name = "features")
)

sys.source(
  here("R", "fun-extractors.R"),
  envir = attach(NULL, name = "extractors")
)

# use ls(features) or ls(extractors) to see the functions

# 02) UTAH POLYGON --------------------------------------------------------

utah <- states() |> 
  filter(NAME == "Utah") |> 
  select(NAME) |> 
  rename_with(tolower) |> 
  st_transform(26912)

write_sf(
  utah, 
  dsn = gpkg, 
  layer = "utah"
)

# 03) WATERSHEDS ----------------------------------------------------------

watersheds <- utah |> 
  # to make sure we pick up the HUC12 inside the HUC8 but outside UT
  st_buffer(30000) |> 
  get_wbd(label = "western_fremont") |> 
  st_transform(26912) |> 
  select(HUC12) |> 
  rename("id" = HUC12) |> 
  mutate(id = substr(id, start = 1, stop = 10)) |> 
  group_by(id) |> 
  summarize()

window <- watersheds |> 
  mutate(id = substr(id, start = 1, stop = 8)) |> 
  group_by(id) |> 
  summarize() |> 
  mutate(id = as.numeric(id)) |> 
  filter(
    id > 16010204,
    id < 16040101, 
    id != 16020307,
    id != 16020309
  ) |> 
  st_union() |> 
  st_as_sf()

# weird holes introduced into this geometry
bob <- st_geometry(window)[[1]][1]
bob <- bob |> 
  st_polygon() |> 
  st_sfc(crs = 26912)

window <- window |> st_set_geometry(bob)

watersheds  <- watersheds |> st_filter(window, .predicate = st_within)

write_sf(
  window, 
  dsn = gpkg, 
  layer = "window"
)

remove(bob)

# 04) SITES ---------------------------------------------------------------

sites <- read_sf(
  here(".misc", "fremont.gpkg"), # <--- can't be run without site data
  layer = "centroids"
) |> 
  st_filter(window)

villages <- here("data", "villages.csv") |> 
  read_csv() |> 
  select(smithtri, features) |> 
  separate_rows(
    features,
    sep = "; "
  ) |> 
  filter(
    !is.na(features)
  ) |> 
  separate(
    features, 
    into = c("type", "count"),
    sep = ":"
  ) |> 
  filter(
    !type %in% c("granary", "cist")
  ) |> 
  group_by(smithtri) |> 
  summarize(
    nfeatures = sum(as.numeric(count))
  ) |> 
  ungroup()

sites <- sites |> 
  left_join(villages, by = "smithtri") |> 
  select(smithtri, affiliation, nfeatures) |> 
  mutate(
    nfeatures = ifelse(is.na(nfeatures), 1, nfeatures)
  )
  
# write_sf(
#   sites,
#   dsn = gpkg,
#   layer = "sites"
# )

# 05) DEM -----------------------------------------------------------------

dem <- window |> 
  get_ned(
    res = "1",
    label = "western_fremont"
  )

dem <- dem |> 
  rast() |> # convert to a spatRaster
  crop(st_transform(window, crs = 4326)) |> 
  project("epsg:26912")

dem <- 
  dem |> 
  resample(
    rast(
      extent = ext(dem), 
      resolution = c(250,250),
      crs = crs(dem)
    )
  ) |> 
  mask(
    vect(window)
  )

slope  <- dem |> terrain("slope")

writeRaster(dem, filename = here("data", "rast-250m_dem.tif"))

# 06) LAND OWNERSHIP ------------------------------------------------------

# From the USGS Protected Areas Database (PAD-US)
layer_url <- paste0(
  "https://gis1.usgs.gov/arcgis/rest/services/",
  "padus2_1/CombinedProclamationMarineFeeDesignationEasement/MapServer/0/query"
)

lands <- download_features(window, layer_url)

lands <- lands |> 
  rename_with(tolower) |> 
  rename(
    "manager" = mang_name,
    "name" = unit_nm
  ) |> 
  filter(mang_type == "FED") |> 
  select(objectid, name, category, manager)

lands <- lands |> 
  st_transform(26912) |> 
  st_intersection(window)

write_sf(
  lands,
  dsn = gpkg,
  layer = "federal_lands"
)

remove(layer_url)

# 07) WATER FEATURES ------------------------------------------------------

waters <- get_nhd(window, label = "western_fremont")

springs <- waters |> 
  pluck("Point") |> 
  rename_with(tolower) |> 
  filter(ftype == 458) |> 
  select(objectid, fcode, gnis_name) |> 
  st_transform(26912)

streams <- waters |> 
  pluck("Flowline") |>
  rename_with(tolower) |> 
  filter(ftype == 46006) |> # streams (460)
  select(objectid, fcode, gnis_name) |> 
  st_transform(26912) |> 
  mutate(type = "perennial streams")

# download perennial streams (fcode=46006)
streams <- download_features(
  window,
  url = "https://hydro.nationalmap.gov/arcgis/rest/services/NHDPlus_HR/MapServer/3/query",
  where = "ftype=460"
) |> 
  select(OBJECTID,gnis_name,ftype,fcode) |> 
  filter(fcode == 46006 | fcode == 46003, !is.na(gnis_name)) |> 
  mutate(type = "streams")

# download artificial paths (this includes major rivers like the Colorado)
artificial_paths <- download_features(
  window,
  url = "https://hydro.nationalmap.gov/arcgis/rest/services/NHDPlus_HR/MapServer/3/query",
  where = "fcode=55800"
) |> 
  select(OBJECTID,gnis_name,ftype,fcode) |> 
  filter(!is.na(gnis_name)) |> 
  mutate(type = "artificial paths")

streams <- streams |> 
  bind_rows(artificial_paths) |> 
  st_transform(26912) |> 
  st_intersection(window)

# ggplot() + 
#   geom_sf(data = utah) + 
#   geom_sf(data = window, fill = "white") + 
#   geom_sf(data = streams, color = "dodgerblue", linewidth = 0.1) + 
#   theme_void()

write_sf(
  springs,
  dsn = gpkg,
  layer = "springs"
)

write_sf(
  streams,
  dsn = gpkg,
  layer = "streams"
)

remove(waters, paths)

# 08) ROADS ---------------------------------------------------------------

nv_roads <- primary_secondary_roads("Nevada")
ut_roads <- primary_secondary_roads("Utah")

roads <- bind_rows(nv_roads, ut_roads) |> 
  rename_with(tolower) |> 
  st_transform(26912) |> 
  st_intersection(st_buffer(utah, 30000))

write_sf(
  roads,
  dsn = gpkg,
  layer = "roads"
)

remove(nv_roads, ut_roads)

# 08) PRISM ---------------------------------------------------------------

# We are using the PRISM LT81 (800m resolutio) dataset, which is not free
# it should be free, but it's not

# see R/prism.R

# 10) TREE RINGS ----------------------------------------------------------

tree_rings <- spData::world |> 
  filter(continent == "North America") |> 
  st_union() |> 
  get_itrdb(
    label = "western_fremont",
    extraction.dir = here("data"),
    recon.years = 1:2000,
    calib.years = 1924:1983,
    measurement.type = c("Earlywood Width", "Latewood Width", "Ring Width"),
    chronology.type = c("ARSTND", "Standard")
  )

# 11) COST-DISTANCE -------------------------------------------------------

# this takes some serious computing, so moving to a separate R script 
# where I'm going to use parallel processing through the furrr package

# see R/cost-distance.R

# 12) EXTRACT DATA --------------------------------------------------------

uncounted_sites <- sites |> 
  uncount(weights = nfeatures) |> 
  st_as_sf()

watersheds <- watersheds |>
  mutate(
    area      = st_area(watersheds) |> units::set_units(km^2),
    sites     = count_sites(watersheds, uncounted_sites),
    elevation = extract_value(watersheds, dem, mean),
    slope     = extract_value(watersheds, slope, mean),
    protected = calculate_overlap(watersheds, lands)
  )

write_sf(
  watersheds, 
  dsn = gpkg, 
  layer = "watersheds"
)
