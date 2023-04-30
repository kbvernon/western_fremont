
# calculate proportion of polygon x that polygon y overlaps
# vectorized to work with dplyr::mutate
calculate_overlap <- function(x,  y) {
  
  suppressWarnings({
    
    area_x <- st_area(x)
    
    area_y <- unlist(
      lapply(1:nrow(x), function(z){
        
        clip <- st_intersection(y, x[z,])
        clip <- st_union(clip)
        
        st_area(clip)
        
      })
    )
    
  })
  
  p <- area_y/area_x
  
  as.numeric(p)
  
}


# have terra::extract() return a vector so it can work in dplyr::mutate()
extract_value <- function(x, y, .fun){
  
  df <- terra::extract(y, vect(x), fun = .fun, na.rm = TRUE)
  
  df[, 2, drop = TRUE]
  
}

# count the number of site points in each watershed polygon
# vectorized for use in dplyr::mutate()
count_sites <- function(x, y) {
  
  i <- sf::st_intersects(x, y)
  
  lengths(i)
  
}
