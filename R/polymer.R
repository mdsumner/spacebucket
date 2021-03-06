new_polymer <- function(input,
                        primitives,
                        geometry_map,
                        index) {
  structure(list(input = input,
                 primitives = primitives,
                 geometry_map = geometry_map,
                 index = index), class = "polymer")
}



#' Polymer
#'
#' Convert a collection of sf data frame polygon layers to a single pool
#' of triangles.
#'
#' Each triangle is identified by which path in the inputs it belongs to. None of
#' this is very useable yet. Holes can be identified but aren't at the moment, any
#' path that is a hole is identified per triangle.
#'
#' `input` is a list with all input objects
#' `primitives` is the triangulation object
#' `geometry_map` is the paths with their row count
#' `index` is the mapping between triangle and path/s
#' @param ... sf polygon data frame inputs
#'
#' @return a polymer, see details
#' @export
#' @importFrom rlang .data
#' @examples
#' polymer(A, B, C)
polymer <- function(...) {
  ## combine each layer
  inputs <- list(...)
  inputs0 <- lapply(seq_along(inputs),
                    function(x) sf::st_sf(layer = rep(x, length(inputs[[x]][[1]])), geometry = sf::st_geometry(inputs[[x]])))
  #  mesh_pool <- silicate::SC(do.call(rbind, inputs0))

  ## TODO1
  ## triangulate the mesh
  sfall <- do.call(rbind, inputs0)
  path <- silicate::PATH(sfall)
  RTri <- pfft_edge_RTriangle(path)

  ## TODO2
  ## identify all points by overlap with inputs
  map <- pfft_path_triangle_map(path, RTri)

  ## TODO3
  ## sort out common CRS for inputs

  index <-   map %>% dplyr::mutate(path_ = match(.data$path_, path$path$path_))
  paths <- path[["path"]] %>%
    dplyr::transmute(.data$subobject,
                     .data$object_,
                     .data$ncoords_,
                     path = dplyr::row_number())

  layers <- unlist(lapply(seq_along(inputs), function(a) rep(a, nrow(inputs[[a]]))))
  paths$layer <- layers[paths$object_]
  new_polymer(input = inputs0,
              primitives = RTri,
              geometry_map = paths,
              index = index)
}

#' Print polymer
#'
#' Print a short description of the polymer contents.
#' @param x polymer
#' @param ... ignored
#'
#' @return x invisibly
#' @export
#'
#' @examples
#' polymer(A, B, C)
print.polymer <- function(x, ...) {
  cat("polymer mesh:\n")
  cat(sprintf("Layers:    %i\n", length(x$input)))
  cat(sprintf("Polygons:  %i\n", sum(unlist(lapply(x$input, nrow)))))
  cat(sprintf("Triangles: %i\n", length(unique(x$index$triangle_idx))))
  cat(sprintf("(Overlaps: %i)\n", sum(table(x$index$triangle_idx) > 1)))
  invisible(x)
}

#' Plot polymer
#'
#' The default plot shows only the mesh. If `show_intersection = TRUE`, the part
#' of the mesh that has 2 intersecting regions or more is contrasted to the rest.
#' @param x polymer
#' @param ... arguments to [polypath]
#' @param show_intersection logical, plot the intersection region contrasted to the pool (default `FALSE`)
#'
#' @return the input, invisibly
#' @export
#' @importFrom graphics plot polypath
#' @importFrom utils head
#' @examples
#' plot(polymer(A, B, C))
#' library(sf)
#' example(st_read)
#' nc <- nc[1:5, ]
#' x <- polymer(nc, st_jitter(nc, amount = 0.1))
#' plot(x)
plot.polymer <- function(x, ..., show_intersection = FALSE) {

  if (show_intersection) {
    plot(x, border = "grey", asp = 1, xlab = "", ylab = "")

    sb_intersection(x, ...)
  } else {
    plot(x$primitives$P, pch = ".", asp = 1, xlab = "", ylab = "", axes = FALSE)
    polypath(head(x$primitives$P[t(cbind(x$primitives$T, x$primitives$T[,1], NA)), ], -1), ...)

  }
  invisible(x)
}
## needs to be in silicate
get_projection.sfc <- function(x, ...) attr(x, "crs")[["proj4string"]]
get_projection.sf <- function(x, ...) attr(sf::st_geometry(x), "crs")[["proj4string"]]

sb_intersection <- function(x, ...) {
  index <- x$index %>%
    dplyr::group_by(.data$triangle_idx) %>%
    dplyr::filter(dplyr::n() > 1) %>% dplyr::ungroup()
  #index$layer <- x$geometry_map$layer[match(index$path_, x$geometry_map$path)]
  triangles <- x$primitives$T[index$triangle_idx, ]
  polypath(head(x$primitives$P[t(cbind(triangles, NA)), ], -1L), ...)
}
