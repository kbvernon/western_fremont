
# some functions for working with ArcGIS REST API
# use feature ids to download features in bundles, work around download size limits

get_ids <- function(envelope, url, where = ""){
  
  query <- list(
    f = "json",
    where = where,
    geometry = envelope,
    geometryType = "esriGeometryEnvelope",
    inSR = 4326, 
    returnIdsOnly = TRUE,
    returnGeometry = FALSE
  )
  
  html <- httr::GET(url, query = query)
  
  guts <- httr::content(
    html, 
    as = "text", 
    encoding = "UTF-8"
  )
  
  json <- jsonlite::fromJSON(guts)
  
  json[['objectIds']]
  
}

get_features <- function(x, url){
  
  objectIds <- paste0(x, collapse = ",")
  
  query <- list(
    f = "json", # gotta use json because geojson is generating bad request errors
    outFields = "*",
    objectIds = objectIds,
    outSR = 4326
  )
  
  html <- httr::GET(url, query = query)
  
  result <- tryCatch(
    {
      features <- httr::content(html, as = "text", encoding = "UTF-8")
      sf::read_sf(features)
    },
    error = function(cond) {
      message(cond)
      message(paste("\n\nfor", objectIds))
      return(NULL)
    }
  )
  
  result
  
}

download_features <- function(envelope, url, where = "", dlsize = 200) {
  
  bb8 <- sf::st_transform(envelope, crs = 4326)
  bb8 <- sf::st_bbox(bb8)
  bb8 <- round(bb8, 4)
  bb8 <- paste(bb8, collapse = ",")
  
  ids <- get_ids(url = url, envelope = bb8, where = where)
  
  ids <- split(ids, ceiling(seq_along(ids)/dlsize))
  
  features <- lapply(ids, get_features, url = url)
  
  do.call("rbind", features)
  
}
