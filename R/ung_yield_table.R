#' A simple table of volume by age, for example for the Carbon Budget Model
#'
#' Returns gross merchantable volume (m3/ha) by age for one or more species,
#' using one model, in the simple layout that yield-table tools such as the
#' Carbon Budget Model expect. Ages start at 0 by default, where volume is 0.
#' Use [plot()] to draw the curves.
#'
#' @section Uncertainty interval:
#' With `uncertainty = TRUE`, the table gets `lower` and `upper` columns: the
#' central 90 % interval (by default) of many simulated volumes. Each
#' simulation uses slightly different climate and slightly different
#' parameters:
#'
#' * **Climate.** `dd0` and `map` are drawn at random around the values you
#'   supplied. By default they vary as much as climate varies among the plots
#'   used to fit that species' model across Canada (`dd0_sd` and `map_sd` in
#'   [ung_envelope]), so the interval is wide. If you know how uncertain your
#'   own climate values are, set `sd_dd0` and `sd_map`.
#' * **Rounding of the parameters.** The authors published every parameter
#'   with only 4 decimal places, and the unrounded values are not available.
#'   Each simulation picks every parameter at random within half a unit of its
#'   last printed digit (for example, 0.1234 becomes a value between 0.12335
#'   and 0.12345). Keep the default `rounding = TRUE`; `rounding = FALSE` only
#'   shows how much of the interval comes from climate alone.
#'
#' The interval does **not** include the statistical uncertainty of the fitted
#' parameters, or the variation of real stands around the model, so real
#' stands vary more than the interval shows.
#'
#' @param species Character vector of species (common name, scientific name or
#'   code; see [ung_species()]). Each species is combined with every age.
#' @param age Numeric vector of ages (years). Default `seq(0, 150, by = 10)`.
#' @param dd0,map Climate for each curve: `NULL` (default; each species uses
#'   the average `dd0` and `map` of the plots used to fit its model, see
#'   [ung_volume()]), one value used for every curve, or one value per
#'   element of `species`.
#' @param model `"Nat2"` (default) or `"Nat1"`. Nat2 is the default because it
#'   predicts average volume directly; see *Which model to use* in
#'   [ung_volume()].
#' @param ... Options for the uncertainty interval, used only when
#'   `uncertainty = TRUE` (see *Uncertainty interval*): `n`, the number of
#'   simulations (default 1000); `interval`, the central probability of the
#'   interval (default 0.9); `sd_dd0` and `sd_map`, the standard deviation of
#'   `dd0` (degree-days) and `map` (mm), one value or one per curve (default:
#'   the species values in [ung_envelope]; 0 holds the variable fixed); `cor`,
#'   the correlation between the `dd0` and `map` draws (default 0); and
#'   `rounding` (default `TRUE`). Arguments after `...` must be named in full.
#' @param id Optional label for each curve, for example a stand ID: one value
#'   per element of `species`. The same label can be repeated, for example for
#'   a stand with two species. When given, it becomes the first column, `id`,
#'   of the result, so each curve can be matched back to its stand. Default
#'   `NULL` (no `id` column).
#' @param nat1_bias_correction Logical. For Nat1 only: `TRUE` corrects the
#'   bias of Nat1 volume; see *Why Nat1 volume needs a correction* in
#'   [ung_volume()]. Default `FALSE`.
#' @param uncertainty Logical. `TRUE` adds `lower` and `upper` columns (see
#'   *Uncertainty interval*). Default `FALSE`.
#' @param seed Optional integer, used only when `uncertainty = TRUE`. The
#'   interval comes from random draws, so without a seed `lower` and `upper`
#'   change slightly each time you run the same call. Give any whole number
#'   (for example `seed = 1`) to get exactly the same interval every time. The
#'   `volume` column is not affected. Default `NULL` (no seed).
#' @param format `"long"` (default): one row per curve and age, with columns
#'   `species`, `model`, `dd0`, `map`, `age`, `volume` (and `lower`, `upper`).
#'   `"wide"`: one row per curve, with columns `species`, `model`, `dd0`,
#'   `map` and one column of volume per age, named `vol_0`, `vol_10`, and so
#'   on. With `uncertainty = TRUE`, the wide table has three rows per curve,
#'   told apart by the column `statistic` (`"volume"`, `"lower"`, `"upper"`).
#'   Both layouts start with an `id` column when `id` is given.
#' @param warn Logical. `FALSE` turns off the summary warning about
#'   predictions outside the data (see [ung_volume()]). Default `TRUE`.
#'
#' @details For several stands, give one value of `species`, `dd0`, `map` and
#'   `id` per curve. For example, a stand `"A"` with black spruce and a stand
#'   `"B"` with black spruce and jack pine:
#'   `ung_yield_table(c("black spruce", "black spruce", "jack pine"), id = c("A", "B", "B"), dd0 = c(1800, 2200, 2200), map = c(600, 900, 900))`.
#'
#'   A yield curve is a longer projection than the authors designed the models
#'   for, and volume is sensitive to climate and to the rounding of the
#'   parameters; see [ung_volume()] and run [ung_check()] on the long table for
#'   details.
#'
#' @return A data.frame of class `ung_yield_table` (see `format`).
#' @seealso [plot.ung_yield_table()], [ung_check()], [ung_volume()]
#' @export
#' @examples
#' # Black spruce at a site in central Saskatchewan, ages 0 to 150
#' tab <- ung_yield_table("black spruce", dd0 = 2194, map = 461)
#' head(tab)
#' plot(tab)
#'
#' # One row per curve, one column per age
#' ung_yield_table(c("black spruce", "jack pine"), age = seq(0, 100, by = 20),
#'                 dd0 = 2194, map = 461, format = "wide")
#'
#' # With an uncertainty interval
#' tab <- ung_yield_table("jack pine", dd0 = 2194, map = 461,
#'                        uncertainty = TRUE, seed = 1)
#' plot(tab)
#'
#' # Nat1 and Nat2 on one plot
#' nat1 <- ung_yield_table("jack pine", dd0 = 2194, map = 461, model = "Nat1",
#'                         nat1_bias_correction = TRUE)
#' nat2 <- ung_yield_table("jack pine", dd0 = 2194, map = 461)
#' plot(rbind(nat1, nat2))
ung_yield_table <- function(species, age = seq(0, 150, by = 10), dd0 = NULL,
                            map = NULL, model = c("Nat2", "Nat1"), ...,
                            id = NULL, nat1_bias_correction = FALSE,
                            uncertainty = FALSE, seed = NULL,
                            format = c("long", "wide"), warn = TRUE) {
  model <- match.arg(model)
  format <- match.arg(format)
  .check_logical(uncertainty, "uncertainty")
  if (!is.null(id) && (length(id) != length(species) || anyNA(id))) {
    stop("`id` must be NULL or have one value (not NA) per element of ",
         "`species`.", call. = FALSE)
  }

  # Predict every species at every age with the chosen model
  curve <- .ung_curve(species, age, dd0 = dd0, map = map, model = model,
                     nat1_bias_correction = nat1_bias_correction, warn = warn)
  out <- data.frame(species = curve$species, model = model,
                    dd0 = curve$dd0, map = curve$map,
                    age = curve$age, volume = curve[[paste0("V_", model)]],
                    stringsAsFactors = FALSE)
  # .ung_curve() returns all ages of curve 1, then curve 2, and so on
  if (!is.null(id)) {
    out <- data.frame(id = rep(id, each = length(age)), out,
                      stringsAsFactors = FALSE)
  }

  # Optional uncertainty interval for the same rows
  if (uncertainty) {
    u <- .ung_uncertainty(curve$species, curve$age, curve$dd0, curve$map,
                         model = model,
                         nat1_bias_correction = nat1_bias_correction,
                         seed = seed, warn = FALSE, ...)
    out$lower <- u$lower
    out$upper <- u$upper
  }

  if (format == "wide") out <- .yield_wide(out)
  attr(out, "nat1_bias_correction") <- nat1_bias_correction
  class(out) <- c("ung_yield_table", "data.frame")
  out
}

# Reshape a long yield table to one row per curve (and statistic) and one
# column per age.
.yield_wide <- function(long) {
  stats_cols <- intersect(c("volume", "lower", "upper"), names(long))
  id_cols <- intersect(c("id", "species", "model", "dd0", "map"), names(long))
  key <- do.call(paste, c(long[id_cols], sep = "|"))
  keys <- unique(key)
  first <- match(keys, key)
  ages <- sort(unique(long$age))

  parts <- lapply(stats_cols, function(s) {
    m <- matrix(NA_real_, length(keys), length(ages),
                dimnames = list(NULL, paste0("vol_", ages)))
    m[cbind(match(key, keys), match(long$age, ages))] <- long[[s]]
    data.frame(long[first, id_cols, drop = FALSE], curve = seq_along(keys),
               statistic = s, m, check.names = FALSE, stringsAsFactors = FALSE)
  })
  wide <- do.call(rbind, parts)
  wide <- wide[order(wide$curve, match(wide$statistic, stats_cols)), ]
  wide$curve <- NULL
  if (length(stats_cols) == 1L) wide$statistic <- NULL
  rownames(wide) <- NULL
  wide
}
