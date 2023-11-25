
get_basemap <- function(x, 
                        map = "physical", 
                        size = c(16000,9000), 
                        dpi = 300,
                        imageSR = 4326) {

  x <- st_bbox(x)

  old_ratio <- (x[["xmax"]] - x[["xmin"]]) / (x[["ymax"]] - x[["ymin"]])
  new_ratio <- (size[[1]] / size[[2]])

  if (!all.equal(old_ratio, new_ratio)) {

    msg <- paste0(
      "Extent of image (size) differs from extent of x (bbox). ",
      "Map may be warped."
    )

    warning(msg, call. = FALSE)

  }

  req <- httr2::request("http://services.arcgisonline.com/arcgis/rest/services")
  
  req <- httr2::req_url_path_append(req, map, "MapServer", "export")
  
  req <- httr2::req_url_query(
    req,
    bbox = paste(x, collapse = ","),
    bboxSR = st_crs(x)$epsg,
    imageSR = imageSR,
    format = "png",
    dpi = dpi,
    size = paste(size, collapse = ","),
    pixelType = "U8",
    noDataInterpretation = "esriNoDataMatchAny",
    interpolation = "+RSP_BilinearInterpolation",
    f = "image"
  )
  
  path <- tempfile(fileext = ".png")
  
  resp <- httr2::req_perform(req, path = path)
  
  png::readPNG(path, native = TRUE)
  
}
