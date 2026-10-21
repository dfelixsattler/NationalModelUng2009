#' Look up climate inputs for the Ung et al. (2009) models with climr
#'
#' Retrieves mean annual precipitation (`map`, mm) and annual degree-days above
#' 0 degrees C (`dd0`) for point locations from 1981-2010 climate normals using
#' the [climr](https://github.com/bcgov/climr) package, so the result can be
#' passed straight to [ung_volume()].
#'
#' `climr` does not provide `DD_0` directly. `dd0` is derived exactly from
#' quantities it does provide, using the identity
#' `sum(T - 18) = DD18 - DDsub18` over a 365-day year:
#' `DD0 = (DD18 - DDsub18) + 365 * 18 + DDsub0`.
#'
#' @section Differences from the paper's climate:
#' Ung et al. (2009) fitted the models to interpolated normals with
#' inter-annual variability restored (McKenney et al. 2001), which are not
#' identical to the `climr` 1981-2010 normals. Expect small differences in `dd0`
#' and `map` which, because the models can be sensitive to climate (see
#' [ung_sensitivity()]), can matter. If you have ClimateNA or ClimateBC output,
#' use its `DD_0` and `MAP` columns directly as `dd0` and `map` instead.
#' Do not use future-climate projections: the authors state the climate terms
#' are descriptive only and not suitable for climate-change impact projection.
#'
#' @section Requirements:
#' The suggested package `climr` must be installed
#' (`remotes::install_github("bcgov/climr")`). The first call downloads and
#' caches climate rasters, which can take several minutes and some hundreds of
#' MB; later calls are fast. Coverage is North America.
#'
#' @param lon,lat Numeric vectors. Longitude and latitude in decimal degrees
#'   (WGS84; longitude negative in the western hemisphere).
#' @param elev Numeric vector. Elevation in metres above sea level.
#' @param id Optional vector of unique identifiers; defaults to row numbers.
#' @param quiet Logical. Suppress the one-line message about the data source.
#'
#' @return A data.frame with columns `id`, `lon`, `lat`, `elev`, `dd0` and `map`.
#' @seealso [ung_volume()]
#' @export
#' @examples
#' \dontrun{
#' clim <- ung_climate(lon = -105.5, lat = 54.1, elev = 500)
#' ung_volume("black spruce", age = 80, dd0 = clim$dd0, map = clim$map)
#' }
ung_climate <- function(lon, lat, elev, id = seq_along(lon), quiet = FALSE) {
  if (!requireNamespace("climr", quietly = TRUE)) {
    stop("package 'climr' is required; install it with ",
         "remotes::install_github(\"bcgov/climr\").", call. = FALSE)
  }
  for (nm in c("lon", "lat", "elev")) {
    v <- get(nm)
    if (!is.numeric(v) || length(v) == 0L || length(v) != length(lon)) {
      stop("`lon`, `lat` and `elev` must be numeric vectors of equal length.",
           call. = FALSE)
    }
    if (anyNA(v)) stop("`", nm, "` contains missing values.", call. = FALSE)
  }
  if (length(id) != length(lon) || anyDuplicated(id)) {
    stop("`id` must be unique and the same length as `lon`.", call. = FALSE)
  }
  if (any(lon > 0)) {
    .ung_warn("some longitudes are positive; Canadian longitudes are negative.",
              "ung2009_warning_climate")
  }
  if (any(lat < 41 | lat > 84 | lon < -141.1 | lon > -52)) {
    .ung_warn(paste("some locations are outside the Canada bounding box; the",
                    "models were fitted to Canadian plots only."),
              "ung2009_warning_climate")
  }

  # Normals for the reference period, one row per location
  xyz <- data.frame(lon = lon, lat = lat, elev = elev, id = id)
  raw <- as.data.frame(climr::downscale(
    xyz = xyz, which_refmap = "refmap_climr", return_refperiod = TRUE,
    vars = c("MAP", "DD18_an", "DDsub18_an", "DDsub0_an")
  ))
  raw <- raw[match(xyz$id, raw$id), , drop = FALSE]

  out <- data.frame(
    id = xyz$id, lon = lon, lat = lat, elev = elev,
    dd0 = raw$DD18_an - raw$DDsub18_an + 365 * 18 + raw$DDsub0_an,
    map = raw$MAP
  )
  rownames(out) <- NULL

  if (anyNA(out$dd0) || anyNA(out$map)) {
    .ung_warn("climate is NA for some locations (outside climr coverage?).",
              "ung2009_warning_climate")
  }
  if (!quiet) {
    message("Climate: climr 1981-2010 normals; dd0 derived from climr degree-day ",
            "variables. See ?ung_climate for differences from the paper's climate.")
  }
  out
}
