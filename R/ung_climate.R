#' Look up climate inputs for the Ung et al. (2009) models with climr
#'
#' Retrieves mean annual precipitation (`map`, mm) and annual degree-days above
#' 0 degrees C (`dd0`) for point locations from 1981-2010 climate normals using
#' the [climr](https://github.com/bcgov/climr) package, so the result can be
#' passed straight to [ung_volume()].
#'
#' **Naming trap:** in `climr` and ClimateNA, `DD_0` / `DDsub0` is degree-days
#' *below* 0 degrees C (a winter-cold measure). It is **not** the `dd0`
#' (degree-days *above* 0 degrees C) the models need, and neither package
#' provides the latter directly. `dd0` is therefore derived from variables
#' `climr` does provide, using `sum(T - 18) = DD18 - DDsub18` over a 365-day
#' year and `DD>0 = sum(T) + DD<0`:
#' `dd0 = (DD18 - DDsub18) + 365 * 18 + DDsub0`.
#' The identity is exact for daily temperatures, but `climr` computes each
#' degree-day variable from monthly mean temperature with separate empirical
#' regressions, so the derived `dd0` is an approximation whose error has not
#' been validated against the degree-days used to fit the models.
#'
#' @section Differences from the paper's climate:
#' Ung et al. (2009) fitted the models to interpolated climate with
#' inter-annual variability restored (McKenney et al. 2001); this is not the
#' same product or period as the `climr` 1981-2010 normals. Expect differences
#' in `dd0` and `map` which, because the models can be sensitive to climate (see
#' [ung_sensitivity()]), can matter. ClimateNA/ClimateBC output cannot simply be
#' substituted: their `DD_0` is degree-days below 0 degrees C. Use
#' [ung_climate_from_climatena()], which derives `dd0` from `DD18`, `DD_18` and
#' `DD_0`.
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
#' @seealso [ung_volume()], [ung_climate_from_climatena()] for a local
#'   ClimateNA or ClimateBC installation
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
    dd0 = .derive_dd0(raw$DD18_an, raw$DDsub18_an, raw$DDsub0_an),
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

# Degree-days above 0 C from the three variables climr / ClimateNA provide:
# DD18 (above 18), DD_18 (below 18) and DD_0 (below 0), all as positive numbers.
.derive_dd0 <- function(dd_above18, dd_below18, dd_below0) {
  dd_above18 - dd_below18 + 365 * 18 + dd_below0
}

#' Convert ClimateNA or ClimateBC output to the climate inputs of the models
#'
#' Use this when you have a local copy of ClimateNA or ClimateBC and do not want
#' to use `climr` (see [ung_climate()]). It takes the annual variables from a
#' ClimateNA/ClimateBC output table and returns `dd0` and `map` ready for
#' [ung_volume()]. It does not run ClimateNA; produce the table first, for
#' example with `run_climatena()` or `run_climatebc()` from the
#' GYClimTransferCFS package, or by running the program yourself.
#'
#' The table must contain the annual variables `MAP`, `DD18`, `DD_18` and `DD_0`
#' (names are matched without regard to capital letters). With the ClimateNA
#' command line, request the annual variable set (`/Y`). `DD_0` and `DD_18` are
#' degree-days *below* 0 and 18 degrees C, `DD18` is degree-days above 18 degrees
#' C; none of them is the `dd0` the models need. `dd0` is derived as
#' `dd0 = (DD18 - DD_18) + 365 * 18 + DD_0`. ClimateNA calculates its degree-day
#' variables from monthly temperatures with regression equations, so this is an
#' approximation whose error has not been validated against the climate used to
#' fit the models (the same caveat as for [ung_climate()]). One consistency check
#' was made: for a point in central Saskatchewan (1981-2010 normals, ClimateNA
#' 7.60), `dd0` from the annual formula was 2194, and `dd0` rebuilt from
#' ClimateNA's monthly variables (`DD_0_xx` plus days times `Tave`) was 2178, a
#' difference of 16 degree-days (0.7 %). That tests the formula against
#' ClimateNA's own monthly values only, not against daily temperatures or the
#' climate used to fit the models.
#'
#' @section Period:
#' Request a climate **normal** (for example `Normal_1981_2010.nrm`) so that the
#' values describe the location over several decades. A single year
#' (`Year_2020.ann`) gives that one year's weather, which is not what the
#' models were fitted to; see the *Climate inputs* section of [ung_volume()].
#' This function does not check which period the table holds.
#'
#' @param x A data.frame of ClimateNA/ClimateBC annual output.
#' @param id Optional name of a column in `x` that identifies each row (for
#'   example `"id2"` in `run_climatena()` output). Defaults to row numbers.
#' @param quiet Logical. Suppress the one-line message.
#'
#' @return A data.frame with columns `id`, `dd0` and `map`, one row per row of `x`.
#' @seealso [ung_climate()], [ung_volume()]
#' @export
#' @examples
#' # Annual normals from ClimateNA 7.60 for lon -105.5, lat 54.1, elev 500 m
#' x <- data.frame(id2 = "stand1", MAP = 461, DD18 = 48, DD_18 = 6467, DD_0 = 2043)
#' ung_climate_from_climatena(x, id = "id2")
ung_climate_from_climatena <- function(x, id = NULL, quiet = FALSE) {
  if (!is.data.frame(x) || nrow(x) == 0L) {
    stop("`x` must be a data.frame with at least one row.", call. = FALSE)
  }
  need <- c("MAP", "DD18", "DD_18", "DD_0")
  hit <- match(tolower(need), tolower(names(x)))
  if (anyNA(hit)) {
    stop("`x` is missing the annual variable(s) ",
         paste(need[is.na(hit)], collapse = ", "),
         ". Request the annual variable set (`/Y`) from ClimateNA/ClimateBC.",
         call. = FALSE)
  }
  v <- lapply(x[hit], as.numeric)
  names(v) <- need

  if (is.null(id)) {
    ids <- seq_len(nrow(x))
  } else if (is.character(id) && length(id) == 1L && tolower(id) %in% tolower(names(x))) {
    ids <- x[[match(tolower(id), tolower(names(x)))]]
  } else {
    stop("`id` must be NULL or the name of a column in `x`.", call. = FALSE)
  }

  if (any(c(v$DD18, v$DD_18, v$DD_0) < 0, na.rm = TRUE)) {
    .ung_warn(paste("DD18, DD_18 and DD_0 should not be negative; check that",
                    "`x` holds annual ClimateNA/ClimateBC variables."),
              "ung2009_warning_climate")
  }
  out <- data.frame(id = ids, dd0 = .derive_dd0(v$DD18, v$DD_18, v$DD_0),
                    map = v$MAP, stringsAsFactors = FALSE)
  if (anyNA(out$dd0) || anyNA(out$map)) {
    .ung_warn("climate is NA for some rows (check the ClimateNA output).",
              "ung2009_warning_climate")
  }
  if (!quiet) {
    message("dd0 derived from ClimateNA/ClimateBC DD18, DD_18 and DD_0. ",
            "See ?ung_climate_from_climatena; use a climate normal, not one year.")
  }
  out
}
