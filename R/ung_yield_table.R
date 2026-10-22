#' A simple table of volume by age, for example for the Carbon Budget Model
#'
#' Returns gross merchantable volume (m3/ha) by age for one or more species,
#' using one model, in the simple layout that yield-table tools such as the
#' Carbon Budget Model expect. Ages start at 0 by default, where volume is 0.
#'
#' @inheritParams ung_curve
#' @param age Numeric vector of ages (years). Default `seq(0, 250, by = 10)`.
#' @param model `"Nat2"` (default) or `"Nat1"`. Nat2 is the default because it
#'   predicts average volume directly; see *Which model to use* in
#'   [ung_volume()].
#' @param uncertainty Logical. `TRUE` adds `lower` and `upper` columns: the
#'   interval from [ung_uncertainty()], which includes climate uncertainty and
#'   the rounding of the parameters. Default `FALSE`.
#' @param format `"long"` (default): one row per species, climate and age, with
#'   columns `species`, `dd0`, `map`, `age`, `volume` (and `lower`, `upper`).
#'   `"wide"`: one row per curve, with columns `species`, `dd0`, `map` and one
#'   column of volume per age, named `vol_0`, `vol_10`, and so on. With
#'   `uncertainty = TRUE`, the wide table has three rows per curve, told apart
#'   by the column `statistic` (`"volume"`, `"lower"`, `"upper"`).
#' @param ... Passed to [ung_uncertainty()] when `uncertainty = TRUE`, for
#'   example `n`, `interval`, `sd_dd0`, `sd_map` or `seed`. Arguments after
#'   `...` must be named in full.
#'
#' @details Each species is combined with every age, as in [ung_curve()]. To
#'   make curves for one species at several sites, repeat the species and give
#'   one `dd0` and `map` per site:
#'   `ung_yield_table(rep("black spruce", 2), dd0 = c(1800, 2200), map = c(600, 900))`.
#'
#'   A yield curve is a longer projection than the authors designed the models
#'   for, and volume is sensitive to climate and to the rounding of the
#'   parameters; see [ung_volume()] and run [ung_check()] on the long table for
#'   details.
#'
#' @return A data.frame (see `format`). The attribute `"model"` records the
#'   model used.
#' @seealso [ung_curve()], [ung_uncertainty()], [ung_check()]
#' @export
#' @examples
#' # Black spruce at a site in central Saskatchewan, ages 0 to 200
#' tab <- ung_yield_table("black spruce", age = seq(0, 200, by = 10),
#'                        dd0 = 2194, map = 461)
#' head(tab)
#'
#' # One row per curve, one column per age
#' ung_yield_table(c("black spruce", "jack pine"), age = seq(0, 100, by = 20),
#'                 dd0 = 2194, map = 461, format = "wide")
#'
#' # With an uncertainty interval
#' ung_yield_table("jack pine", age = seq(0, 100, by = 20), dd0 = 2194,
#'                 map = 461, uncertainty = TRUE, seed = 1)
ung_yield_table <- function(species, age = seq(0, 250, by = 10), dd0 = NULL,
                            map = NULL, model = c("Nat2", "Nat1"), ...,
                            nat1_bias_correction = FALSE, uncertainty = FALSE,
                            format = c("long", "wide"), warn = TRUE) {
  model <- match.arg(model)
  format <- match.arg(format)
  .check_logical(uncertainty, "uncertainty")

  # Predict every species at every age with the chosen model
  curve <- ung_curve(species, age, dd0 = dd0, map = map, model = model,
                     nat1_bias_correction = nat1_bias_correction, warn = warn)
  out <- data.frame(species = curve$species, dd0 = curve$dd0, map = curve$map,
                    age = curve$age, volume = curve[[paste0("V_", model)]],
                    stringsAsFactors = FALSE)

  # Optional uncertainty interval for the same rows
  if (uncertainty) {
    u <- ung_uncertainty(curve$species, curve$age, curve$dd0, curve$map,
                         model = model,
                         nat1_bias_correction = nat1_bias_correction,
                         warn = FALSE, ...)
    out$lower <- u$lower
    out$upper <- u$upper
  }

  if (format == "wide") out <- .yield_wide(out)
  attr(out, "model") <- model
  attr(out, "nat1_bias_correction") <- nat1_bias_correction
  out
}

# Reshape a long yield table to one row per curve (and statistic) and one
# column per age.
.yield_wide <- function(long) {
  stats_cols <- intersect(c("volume", "lower", "upper"), names(long))
  key <- paste(long$species, long$dd0, long$map, sep = "|")
  keys <- unique(key)
  first <- match(keys, key)
  ages <- sort(unique(long$age))

  parts <- lapply(stats_cols, function(s) {
    m <- matrix(NA_real_, length(keys), length(ages),
                dimnames = list(NULL, paste0("vol_", ages)))
    m[cbind(match(key, keys), match(long$age, ages))] <- long[[s]]
    data.frame(long[first, c("species", "dd0", "map")], curve = seq_along(keys),
               statistic = s, m, check.names = FALSE, stringsAsFactors = FALSE)
  })
  wide <- do.call(rbind, parts)
  wide <- wide[order(wide$curve, match(wide$statistic, stats_cols)), ]
  wide$curve <- NULL
  if (length(stats_cols) == 1L) wide$statistic <- NULL
  rownames(wide) <- NULL
  wide
}
