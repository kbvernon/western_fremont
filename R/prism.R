
# Extract PRISM Data (LT81, 800-m resolution)
# and prepare it for PaleoCAR climate reconstruction

##############################.
#     Table of Contents
# 01. Preamble
# 02. Western US
# 03. Precipitation
# 04. Temperature maximum
# 05. Temperature minimum
# 06. Maize GDD
##############################.

# Note: 
# 1- LT81 is behind a paywall (http://www.prism.oregonstate.edu),
#    and you can't run this code without it!
# 2- This code is adapted from Bocinsky (2016) 
# 3- The basic idea behind paleocar is to model climate trends in an area of 
#    interest as a function of tree-ring chronologies over a much, much wider area.
# 4- The aoi for this project is western Utah.

# 01) PREAMBLE ------------------------------------------------------------

library(here)
library(sf)
library(terra)
library(tidyverse)

# geopackage database
gpkg <- here("data", "western-fremont.gpkg")

# coordinate reference 
# EPSG:4326 (WGS84)

# This MUST point to the LT81 dataset 
prism <- "D:/PRISM_800m_DATA"

# years required, 1924-1983 
# specified in list.files(pattern = years)
# complicated to get a regex to handle a range of numbers, so it's a bit messy 

# 02) PROJECT WINDOW ------------------------------------------------------

window <- read_sf(gpkg, layer = "window") |> 
  st_buffer(1000) |> 
  st_transform(4326)

watersheds <- read_sf(gpkg, layer = "watersheds")

# 03) PRECIPITATION -------------------------------------------------------

# including 1923 to get full 1924 water-year
# water-year = October to September 

zipfiles <- prism |> 
  file.path("ppt") |> 
  list.files(
    full.names = TRUE, 
    pattern = "((198[0-3])|(19[3-7][0-9]{1})|(192[3-9])).zip$"
  )

exdir <- file.path(tempdir(), "ppt")

dir.create(exdir)

# unzip returns a vector of paths to unzipped files
files <- lapply(zipfiles, unzip, exdir = exdir)

files <- files |> 
  unlist() |> 
  str_subset(".bil$") |> 
  str_sort()

ppt <- rast(files)

# get year+month (eg., 198203)
names(ppt) <- str_extract(basename(files), "[0-9]{6}") 

ppt <- crop(ppt, vect(window))

remove(zipfiles, exdir, files)

# 04) WATER-YEAR ----------------------------------------------------------

# a simple way to get the water-year is to 
# 1) move Oct, Nov, Dec up one year and then
# 2) subset and sum by year
year  <- substr(names(ppt), 1, 4)
month <- substr(names(ppt), 5, 6)

i <- which(as.numeric(month) > 9)

year[i] <- as.numeric(year[i]) + 1 # advance one year

names(ppt) <- year

ppt <- terra::subset(ppt, which(names(ppt) %in% 1924:1983))

# sum by groups of layers (months in each year)
# and write to disk (this takes a hot minute)
terra::tapp(
  ppt,
  index = rep(1:60, each = 12), # this index does the grouping
  fun = sum,
  filename = here("data", "rast-800m_ppt.tif")
)

remove(year, month, i)
gc()

# 05) TEMPERATURE MAXIMUM -------------------------------------------------

# Maize growing season: May to September
# so, we only want tmax and tmin for those months

zipfiles <- prism |> 
  file.path("tmax") |> 
  list.files(
    full.names = TRUE, 
    pattern = "((198[0-3])|(19[3-7][0-9]{1})|(192[4-9])).zip$"
  )

files_to_extract <- lapply(zipfiles, function(x) {
  
  year <- str_extract(x, "19[0-9]{2}")
  
  target_months <- paste0(year, "0", 5:9, collapse = "|") # may to september
  
  unzip(x, list = TRUE) |> # list = TRUE is like list.files() for zipfiles
    pull(Name) |> 
    str_subset(target_months)
  
})

exdir <- file.path(tempdir(), "tmax")

dir.create(exdir)

files <- mapply(
  unzip, 
  zipfile = zipfiles,
  files = files_to_extract,
  MoreArgs = list(exdir = exdir)
)

files <- files |> 
  unlist() |> 
  str_subset(".bil$") |> 
  str_sort()

tmax <- rast(files)

names(tmax) <- str_extract(basename(files), "[0-9]{6}") 

tmax <- crop(tmax, vect(window))

remove(zipfiles, exdir, files, files_to_extract)
gc()

# 06) TEMPERATURE MINIMUM -------------------------------------------------

zipfiles <- prism |> 
  file.path("tmin") |> 
  list.files(
    full.names = TRUE, 
    pattern = "((198[0-3])|(19[3-7][0-9]{1})|(192[4-9])).zip$"
  )

files_to_extract <- lapply(zipfiles, function(x) {
  
  year <- str_extract(x, "19[0-9]{2}")
  
  target_months <- paste0(year, "0", 5:9, collapse = "|") # may to september
  
  unzip(x, list = TRUE) |> # list = TRUE is like list.files() for zipfiles
    pull(Name) |> 
    str_subset(target_months)
  
})

exdir <- file.path(tempdir(), "tmin")

dir.create(exdir)

files <- mapply(
  unzip, 
  zipfile = zipfiles,
  files = files_to_extract,
  MoreArgs = list(exdir = exdir)
)

files <- files |> 
  unlist() |> 
  str_subset(".bil$") |> 
  str_sort()

tmin <- rast(files)

names(tmin) <- str_extract(basename(files), "[0-9]{6}") 

tmin <- crop(tmin, vect(window))

remove(zipfiles, exdir, files, files_to_extract)
gc()

# 07) MAIZE GDD -----------------------------------------------------------

tbase <- 10
tcap  <- 30

# Lift tmax and tmin to tbase
tmin[ tmin < tbase ] <- tbase
tmax[ tmax < tbase ] <- tbase

# Lower tmax and tmin to tcap
tmin[ tmin > tcap ] <- tcap
tmax[ tmax > tcap ] <- tcap

gdd <- ((tmin+tmax)/2) - tbase

# We now have the daily average by month
# To get the complete growing season, multiply by number of days in month
# Note: the next bit of code requires that the layers be in order, which they are
# because we did str_sort() on the filenames above before reading in the stack
number_of_days <- gdd |> 
  names() |> 
  substr(5, 6) |> 
  unique() |> 
  as.integer() |> 
  lubridate::days_in_month() |> 
  unname()

gdd <- gdd * number_of_days # the shorter vector (5 months) gets recycled

# sum by groups of layers (months in each year)
# and write to disk (this takes a hot minute)
terra::tapp(
  gdd,
  index = rep(1:60, each = 5), # this index does the grouping
  fun = sum,
  filename = here("data", "rast-800m_gdd.tif")
)

