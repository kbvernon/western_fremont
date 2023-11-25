
# trim all white space around image, but then add a few white pixels back (dx, dy)
prepare_image <- function(x, dx = 2, dy = 30, color = "white") {
  
  img <- magick::image_read(path = x)
  
  img <- magick::image_trim(img)
  
  info <- magick::image_info(img)
  
  new_width <- info$width + dx
  new_height <- info$height + dy
  
  img <- magick::image_extent(
    img, 
    magick::geometry_area(new_width, new_height), 
    color = color
  )
  
  magick::image_write(img, path = x)
  
}