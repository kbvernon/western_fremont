
# this is a modification of hf_survey() that loops over origins,
# running in parallel and returning a vector, 
# for use in dplyr::mutate()
# not sure this is the most efficient way to do this
# would like to try some pre-processing of the graph in the future
survey_parallel <- function(terrain, from, ngroups = 500){
  
  rr <- terra::rast(
    nrow   = terrain$nrow,
    ncol   = terrain$ncol,
    extent = terra::ext(terrain$bb8),
    crs    = terrain$crs
  )
  
  from_xy <- sf::st_coordinates(from)[, 1:2, drop = FALSE]
  
  from_cells <- terra::cellFromXY(rr, from_xy)
  
  groups <- as.numeric(
    gl(
      n = nrow(from),
      k = ngroups,
      length = nrow(from)
    )
  )
  
  from_cells <- split(from_cells, groups)
  
  to_cells <- unique(as.integer(terrain$conductance@j)) + 1
  
  graph <- igraph::graph_from_adjacency_matrix(
    terrain$conductance,
    mode = "directed",
    weighted = TRUE
  )
  
  # invert conductance to get travel cost
  igraph::E(graph)$weight <- (1/igraph::E(graph)$weight)
  
  cat("Building cost-distance matrices.\n")
  
  p <- progressr::progressor(length(from)/2)
  
  cost <- furrr::future_map(
    from_cells,
    survey,
    to = to_cells,
    graph = graph,
    p = p
  )
  
  cat("\nBuilding aggregate cost-distance raster.\n\n")
  
  rasterize(cost, rr, to_cells)
  
}

survey <- function(from, to, graph, p){
  
  cost <- igraph::distances(graph, from, to, mode = "out")
  
  cost <- apply(cost, 2, min)
  
  p()
  
  invisible(gc())
  
  return(cost)
  
}

rasterize <- function(x, r, to_cells){
  
  r[] <- NA
  
  r <- rep(r, length(x))
  
  for (i in seq_along(x)){
    
    r[[i]][to_cells] <- x[[i]]
    
  }
  
  min(r, na.rm = TRUE)
  
}