#' Get the climate inputs of the models for stand locations
#'
#' Returns degree-days above 0 degrees C (`dd0`) and mean annual precipitation
#' (`map`, mm) for each stand location, ready for [ung_yield_table()]. The
#' values come from either [climr](https://github.com/bcgov/climr) (an R package) or a local copy of
#' ClimateNA (a Windows program), averaged over 1981-2010 or over the years
#' you choose.
#'
#' If you already have `dd0` and `map` from another source, you do not need
#' this function: pass your values directly to the model functions. If you ran
#' ClimateNA yourself, [ung_climate_from_climatena()] converts its output.
#'
#' **Beware the names.** The models need degree-days *above* 0 degrees C
#' (`dd0`). Neither climr nor ClimateNA provides that variable. Their `DDsub0`
#' (climr) and `DD_0` (ClimateNA) are degree-days *below* 0 degrees C, a
#' measure of how cold the winter is: the opposite quantity. Never pass
#' `DDsub0`, `DD_0` or `DD5` as `dd0`. See the table in the *Climate inputs*
#' section of [ung_models].
#'
#' **How `dd0` is calculated.** Both programs provide degree-days above 18
#' degrees C (`DD18`), below 18 degrees C (`DDsub18`, ClimateNA `DD_18`) and
#' below 0 degrees C (`DDsub0`, ClimateNA `DD_0`). In words: `DD18 - DDsub18`
#' is the yearly total of (daily temperature minus 18); adding `365 * 18`
#' gives the yearly total of daily temperature; adding back the below-zero
#' degree-days (`DDsub0`) removes the effect of the cold days, leaving
#' degree-days above 0 degrees C:
#' `dd0 = (DD18 - DDsub18) + 365 * 18 + DDsub0`.
#' This would be exact with daily temperatures. Both programs, however,
#' estimate each degree-day variable from monthly mean temperatures with
#' regression equations, so the calculated `dd0` is an approximation. It has
#' not been compared with the degree-days the authors used to fit the models.
#'
#' @section Differences from the paper's climate:
#' Ung et al. (2009) used interpolated long-term climate "to which inter-annual
#' variability has been restored" (McKenney et al. 2001; see *Climate inputs*
#' in [ung_models] for what this means). That is not the same product or
#' period as the climr or ClimateNA values. Expect some differences in `dd0`
#' and `map`; because predicted volume can be sensitive to climate (see
#' [ung_check()]), they can matter.
#' Do not use future-climate projections: the authors state the climate terms
#' are descriptive only and not suitable for climate-change impact projection.
#'
#' @section Requirements:
#' **climr:** the suggested package `climr` must be installed
#' (`remotes::install_github("bcgov/climr")`). climr downloads climate maps
#' from a database server the first time an area is requested, which can take
#' several minutes, and keeps them on your computer; later calls for the same
#' area are fast and work offline. Some networks, including some government
#' VPNs, block the database server. climr then reports "Could not establish
#' connection to database". Disconnect from the VPN, or use ClimateNA.
#'
#' **ClimateNA:** Windows only. Give the path to the program in `exe`; its
#' folder must be writable. ClimateNA is run once for the 1981-2010 averages,
#' or once per year in `years`.
#'
#' @param lon,lat Numeric vectors. Longitude and latitude in decimal degrees
#'   (WGS84; longitude negative in the western hemisphere). One location per
#'   stand.
#' @param elev Numeric vector. Elevation in metres above sea level.
#' @param id Optional vector of unique stand identifiers; defaults to row
#'   numbers.
#' @param years `NULL` (default) for the 1981-2010 averages, or the years to
#'   average, such as `2010:2019`.
#' @param source `"climr"` (default) or `"climatena"`.
#' @param exe For `source = "climatena"`: path to the ClimateNA program, for
#'   example `"C:/ClimateNA_v760/ClimateNA_v7.60.exe"`.
#' @param quiet Logical. Suppress the one-line message about the data source.
#'
#' @return A data.frame with columns `id`, `lon`, `lat`, `elev`, `dd0` and
#'   `map`, one row per location.
#' @seealso [ung_yield_table()], [ung_climate_from_climatena()]
#' @export
#' @examples
#' \dontrun{
#' # 1981-2010 averages from climr
#' clim <- ung_climate(lon = -105.5, lat = 54.1, elev = 500)
#' ung_yield_table("black spruce", dd0 = clim$dd0, map = clim$map)
#'
#' # Average of 2010 to 2019 from ClimateNA
#' ung_climate(lon = -105.5, lat = 54.1, elev = 500, years = 2010:2019,
#'             source = "climatena",
#'             exe = "C:/ClimateNA_v760/ClimateNA_v7.60.exe")
#' }
ung_climate <- function(lon, lat, elev, id = seq_along(lon), years = NULL,
                        source = "climr", exe = NULL,
                        quiet = FALSE) {
  source <- .check_choice(source, c("climr", "climatena"), "source")
  .check_locations(lon, lat, elev, id)
  if (!is.null(years) && (!is.numeric(years) || length(years) == 0L ||
                          anyNA(years) || any(years != round(years)))) {
    stop("`years` must be NULL or a vector of whole years, such as 2010:2019.",
         call. = FALSE)
  }

  clim <- if (source == "climr") {
    .climr_climate(lon, lat, elev, id, years)
  } else {
    .climatena_climate(lon, lat, elev, id, years, exe)
  }
  out <- data.frame(id = id, lon = lon, lat = lat, elev = elev,
                    dd0 = clim$dd0, map = clim$map)
  rownames(out) <- NULL

  if (anyNA(out$dd0) || anyNA(out$map)) {
    .ung_warn("climate is NA for some locations (outside the climate data?).")
  }
  if (!quiet) {
    period <- if (is.null(years)) {
      "1981-2010 averages"
    } else {
      paste0("average of ", min(years), "-", max(years), " (", length(years),
             " years)")
    }
    message("Climate: ", if (source == "climr") "climr" else "ClimateNA", " ",
            period, "; dd0 calculated from degree-days above 18, below 18 and ",
            "below 0 degrees C (see ?ung_climate).")
  }
  out
}

# climr: dd0 and map per location, in the order of `id`.
.climr_climate <- function(lon, lat, elev, id, years) {
  if (!requireNamespace("climr", quietly = TRUE)) {
    stop("package 'climr' is required; install it with ",
         "remotes::install_github(\"bcgov/climr\"), or use source = \"climatena\".",
         call. = FALSE)
  }
  xyz <- data.frame(lon = lon, lat = lat, elev = elev, id = id)
  vars <- c("MAP", "DD18_an", "DDsub18_an", "DDsub0_an")
  raw <- if (is.null(years)) {
    climr::downscale(xyz = xyz, which_refmap = "refmap_climr",
                     return_refperiod = TRUE, vars = vars)
  } else {
    climr::downscale(xyz = xyz, which_refmap = "refmap_climr",
                     return_refperiod = FALSE, obs_years = years,
                     obs_ts_dataset = "climatena", vars = vars)
  }
  raw <- as.data.frame(raw)
  # With years there is one row per location and year: average them
  dd0 <- tapply(.derive_dd0(raw$DD18_an, raw$DDsub18_an, raw$DDsub0_an),
                as.character(raw$id), mean)
  map <- tapply(raw$MAP, as.character(raw$id), mean)
  k <- match(as.character(id), names(dd0))
  list(dd0 = as.numeric(dd0[k]), map = as.numeric(map[k]))
}

# ClimateNA: dd0 and map per location, in the order of `id`.
.climatena_climate <- function(lon, lat, elev, id, years, exe) {
  if (.Platform$OS.type != "windows") {
    stop("ClimateNA runs on Windows only. Use source = \"climr\".", call. = FALSE)
  }
  if (is.null(exe) || !is.character(exe) || length(exe) != 1L || !file.exists(exe)) {
    stop("`exe` must be the path to the ClimateNA program, for example ",
         "\"C:/ClimateNA_v760/ClimateNA_v7.60.exe\".", call. = FALSE)
  }
  if (any(grepl(",", as.character(id)))) {
    stop("`id` must not contain commas.", call. = FALSE)
  }
  exe_dir <- dirname(normalizePath(exe))
  periods <- if (is.null(years)) "Normal_1981_2010.nrm" else paste0("Year_", years, ".ann")
  missing_files <- setdiff(periods, list.files(file.path(exe_dir, "Perioddat")))
  if (length(missing_files) > 0L) {
    stop("ClimateNA has no climate data for ",
         paste(missing_files, collapse = ", "), ".", call. = FALSE)
  }
  runs <- lapply(periods, .climatena_run, exe = exe, exe_dir = exe_dir,
                 id = id, lon = lon, lat = lat, elev = elev)
  mean_of <- function(v) Reduce(`+`, lapply(runs, `[[`, v)) / length(runs)
  list(dd0 = mean_of("dd0"), map = mean_of("map"))
}

# Run ClimateNA once for one period file; returns dd0 and map in the order of `id`.
.climatena_run <- function(period, exe, exe_dir, id, lon, lat, elev,
                           timeout = 600) {
  # ClimateNA needs file names relative to its own folder
  tag <- gsub("[^A-Za-z0-9_]", "",
              paste0("ung_", Sys.getpid(), "_", format(Sys.time(), "%H%M%OS3")))
  f_in <- paste0(tag, "_in.csv")
  f_out <- paste0(tag, "_out.csv")
  old <- setwd(exe_dir)
  on.exit({
    unlink(c(f_in, f_out))
    setwd(old)
  }, add = TRUE)
  utils::write.csv(data.frame(ID1 = id, ID2 = "", lat = lat, long = lon,
                              el = elev),
                   f_in, row.names = FALSE, quote = FALSE)
  system2(basename(exe), c("/Y", paste0("/", period), paste0("/", f_in),
                           paste0("/", f_out)), wait = TRUE)

  # ClimateNA can return before the output is written: wait until it is
  # complete (one line per location plus the header)
  start <- Sys.time()
  repeat {
    if (file.exists(f_out) &&
        length(readLines(f_out, warn = FALSE)) >= length(lon) + 1L) break
    if (difftime(Sys.time(), start, units = "secs") > timeout) {
      stop("ClimateNA did not finish ", period, " within ", timeout,
           " seconds.", call. = FALSE)
    }
    Sys.sleep(0.5)
  }
  Sys.sleep(0.5)
  clim <- ung_climate_from_climatena(utils::read.csv(f_out), id = "ID1",
                                     quiet = TRUE)
  k <- match(as.character(id), trimws(as.character(clim$id)))
  list(dd0 = clim$dd0[k], map = clim$map[k])
}

# Shared checks of point locations for ung_climate().
.check_locations <- function(lon, lat, elev, id) {
  for (v in list(lon = lon, lat = lat, elev = elev)) {
    if (!is.numeric(v) || length(v) == 0L || length(v) != length(lon)) {
      stop("`lon`, `lat` and `elev` must be numeric vectors of equal length.",
           call. = FALSE)
    }
  }
  for (nm in c("lon", "lat", "elev")) {
    if (anyNA(list(lon = lon, lat = lat, elev = elev)[[nm]])) {
      stop("`", nm, "` contains missing values.", call. = FALSE)
    }
  }
  if (length(id) != length(lon) || anyDuplicated(id)) {
    stop("`id` must be unique and the same length as `lon`.", call. = FALSE)
  }
  if (any(lon > 0)) {
    .ung_warn("some longitudes are positive; Canadian longitudes are negative.")
  }
  if (any(lat < 41 | lat > 84 | lon < -141.1 | lon > -52)) {
    .ung_warn(paste("some locations are outside the Canada bounding box; the",
                    "models were fitted to Canadian plots only."))
  }
  invisible(NULL)
}

# Degree-days above 0 C from the three variables climr / ClimateNA provide:
# DD18 (above 18), DD_18 (below 18) and DD_0 (below 0), all as positive numbers.
.derive_dd0 <- function(dd_above18, dd_below18, dd_below0) {
  dd_above18 - dd_below18 + 365 * 18 + dd_below0
}

#' Convert ClimateNA or ClimateBC output to the climate inputs of the models
#'
#' Use this when you have run ClimateNA or ClimateBC yourself. It takes the
#' annual variables from a ClimateNA/ClimateBC output table and returns `dd0`
#' and `map` ready for [ung_yield_table()]. It does not run ClimateNA; to run it
#' from R, use `ung_climate(source = "climatena")`, which calls this
#' function on the result.
#'
#' The table must contain the annual variables `MAP`, `DD18`, `DD_18` and `DD_0`
#' (names are matched without regard to capital letters). With the ClimateNA
#' command line, request the annual variable set (`/Y`).
#'
#' **Beware the names.** In ClimateNA, `DD_0` is degree-days *below* 0 degrees
#' C (how cold the winter is), the opposite of the `dd0` the models need, and
#' `DD5` is degree-days above 5 degrees C. Never pass either as `dd0`. Instead,
#' `dd0` is calculated from three ClimateNA variables, degree-days above 18
#' degrees C (`DD18`), below 18 degrees C (`DD_18`) and below 0 degrees C
#' (`DD_0`), as `dd0 = (DD18 - DD_18) + 365 * 18 + DD_0`; the reasoning is
#' explained in [ung_climate()]. ClimateNA estimates its degree-day variables
#' from monthly temperatures with regression equations, so this is an
#' approximation that has not been compared with the climate the authors used
#' to fit the models (the same caveat as for [ung_climate()]). One consistency check
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
#' models were fitted to; see the *Climate inputs* section of [ung_models].
#' This function does not check which period the table holds.
#'
#' @param x A data.frame of ClimateNA/ClimateBC annual output.
#' @param id Optional name of a column in `x` that identifies each row (for
#'   example `"ID1"` in ClimateNA output). Defaults to row numbers.
#' @param quiet Logical. Suppress the one-line message.
#'
#' @return A data.frame with columns `id`, `dd0` and `map`, one row per row of `x`.
#' @seealso [ung_climate()], [ung_yield_table()]
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
                    "`x` holds annual ClimateNA/ClimateBC variables."))
  }
  out <- data.frame(id = ids, dd0 = .derive_dd0(v$DD18, v$DD_18, v$DD_0),
                    map = v$MAP, stringsAsFactors = FALSE)
  if (anyNA(out$dd0) || anyNA(out$map)) {
    .ung_warn("climate is NA for some rows (check the ClimateNA output).")
  }
  if (!quiet) {
    message("dd0 derived from ClimateNA/ClimateBC DD18, DD_18 and DD_0. ",
            "See ?ung_climate_from_climatena; use a climate normal, not one year.")
  }
  out
}
