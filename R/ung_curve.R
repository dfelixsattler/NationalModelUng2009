#' Yield curves for one or more species
#'
#' Predicts volume for every combination of the given species and ages. This is
#' the simplest way to draw yield curves: [ung_volume()] matches its arguments
#' row by row, so `ung_volume(c("black spruce", "Douglas-fir"), 10:80)` is an
#' error (two species, 71 ages), whereas `ung_curve()` returns 71 ages for each
#' species.
#'
#' @inheritParams ung_volume
#' @param species Character vector of species (common name, scientific name or
#'   code; see [ung_species()]).
#' @param age Numeric vector of ages (years). Default `10:150`.
#' @param dd0,map Climate for each species: `NULL` (default; each species uses
#'   the average `dd0` and `map` of the plots used to fit its model, see
#'   [ung_volume()]), one value used for every species, or one value
#'   per species.
#'
#' @details A curve covers more than 10 years of age, so by default
#'   [ung_volume()] issues the `ung2009_warning_horizon` warning. See the
#'   section *Intended use and time horizon* in [ung_volume()]. Set
#'   `warn = FALSE` to hide it.
#'
#' @return A data.frame of class `ung_volume` (see [ung_volume()]) with one row
#'   per species and age. Use [plot()] to draw it.
#' @seealso [ung_volume()], [ung_uncertainty()]
#' @export
#' @examples
#' curves <- ung_curve(c("black spruce", "Douglas-fir"), age = 10:150,
#'                     warn = FALSE)
#' plot(curves)
#'
#' # One climate for every species
#' plot(ung_curve(c("white spruce", "jack pine"), dd0 = 2200, map = 600,
#'                warn = FALSE))
ung_curve <- function(species, age = 10:150, dd0 = NULL, map = NULL,
                      model = c("both", "Nat1", "Nat2"), warn = TRUE) {
  model <- match.arg(model)
  codes <- .resolve_species(species)
  ns <- length(codes)

  per_species <- function(v, nm) {
    if (is.null(v)) return(NULL)
    if (!is.numeric(v) || !length(v) %in% c(1L, ns)) {
      stop("`", nm, "` must be NULL, one value, or one value per species.",
           call. = FALSE)
    }
    rep_len(v, ns)
  }
  dd0 <- per_species(dd0, "dd0")
  map <- per_species(map, "map")

  if (!is.numeric(age) || length(age) == 0L) {
    stop("`age` must be a non-empty numeric vector.", call. = FALSE)
  }
  s <- rep(seq_len(ns), each = length(age))

  ung_volume(codes[s], rep(age, times = ns),
             dd0 = if (is.null(dd0)) NULL else dd0[s],
             map = if (is.null(map)) NULL else map[s],
             model = model, warn = warn)
}
