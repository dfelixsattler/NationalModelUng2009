#' Climate-uncertainty fan for predicted volume
#'
#' Propagates uncertainty in the climate inputs through the models by Monte
#' Carlo sampling. For each stand, `n` pairs of (`dd0`, `map`) are drawn from a
#' bivariate normal distribution centred on the supplied (or species-mean)
#' climate, volume is predicted for every draw, and the median and a central
#' interval of the predictions are returned.
#'
#' @section What the spread means:
#' * By default the standard deviations are the species-level SDs of the climate
#'   of the fitting plots (`dd0_sd`, `map_sd` in [ung_envelope]). These describe
#'   **spatial variation among plots**, not year-to-year variation, and not the
#'   error of any particular climate dataset. They answer "how much would the
#'   prediction move for a location that differs from this one by a typical
#'   among-plot climate difference?". If you know the uncertainty of your own
#'   climate values (for example from a climate-product comparison), pass it as
#'   `sd_dd0` and `sd_map`.
#' * Only **climate uncertainty** is propagated. Parameter uncertainty and
#'   residual (plot-to-plot) variation of the models are not included, so the
#'   interval is not a prediction interval for a stand's volume.
#' * Draws are **untruncated** normal values, bounded below at 0 because
#'   degree-days and precipitation cannot be negative. `dd0` and `map` are
#'   independent unless you set `cor`; their correlation in the fitting data is
#'   not available.
#' * `prop_outside` is the share of draws whose climate falls outside the
#'   fitting-data range of the species (see [ung_envelope]); a large share means
#'   the fan is largely extrapolation.
#'
#' @inheritParams ung_volume
#' @param n Number of Monte Carlo draws per stand (at least 10). Default 1000.
#' @param sd_dd0,sd_map Standard deviation of `dd0` (degree-days) and `map` (mm).
#'   A single number, a vector with one value per stand, or `NULL` (default) to
#'   use the species SDs from [ung_envelope]. Use 0 to hold a variable fixed.
#' @param cor Correlation between the `dd0` and `map` draws, in (-1, 1).
#'   Default 0.
#' @param interval Central probability of the interval, in (0, 1). Default 0.9
#'   (5th to 95th percentile).
#' @param seed Optional integer for reproducible draws. The global random
#'   number state is restored afterwards.
#' @param warn Logical. `FALSE` skips the diagnostic warnings and messages of
#'   [ung_volume()] for the central prediction.
#'
#' @return A data.frame of class `ung_uncertainty` with one row per input row
#'   and model: `row`, `species`, `age`, `dd0`, `map`, `sd_dd0`, `sd_map`,
#'   `model`, `volume` (m3/ha at the central climate), `median`, `lower`,
#'   `upper` (m3/ha), and `prop_outside`.
#' @seealso [ung_volume()], [ung_sensitivity()]
#' @export
#' @examples
#' # Fan across ages for white spruce at a stated climate
#' f <- ung_uncertainty("white spruce", age = seq(20, 200, by = 20),
#'                      dd0 = 1800, map = 700, seed = 1)
#' head(f)
#' plot(f)
#'
#' # Typical-stand fan with a user-supplied climate uncertainty
#' ung_uncertainty("jack pine", age = 80, sd_dd0 = 100, sd_map = 50, seed = 1)
ung_uncertainty <- function(species, age, dd0 = NULL, map = NULL,
                            model = c("both", "Nat1", "Nat2"),
                            n = 1000, sd_dd0 = NULL, sd_map = NULL, cor = 0,
                            interval = 0.9, seed = NULL, warn = TRUE) {
  model <- match.arg(model)
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 10) {
    stop("`n` must be a single number of at least 10.", call. = FALSE)
  }
  n <- as.integer(n)
  if (!is.numeric(cor) || length(cor) != 1L || is.na(cor) || abs(cor) >= 1) {
    stop("`cor` must be a single number between -1 and 1 (exclusive).", call. = FALSE)
  }
  if (!is.numeric(interval) || length(interval) != 1L || is.na(interval) ||
      interval <= 0 || interval >= 1) {
    stop("`interval` must be a single number between 0 and 1 (exclusive).", call. = FALSE)
  }
  if (!is.null(seed) && (!is.numeric(seed) || length(seed) != 1L || is.na(seed))) {
    stop("`seed` must be NULL or a single number.", call. = FALSE)
  }

  x <- .prepare_inputs(species, age, dd0, map)
  if (isTRUE(warn)) .note_defaults(x)
  rows <- nrow(x)
  env <- .envelope_for(x$species)
  sd_dd0 <- .resolve_sd(sd_dd0, env$dd0_sd, rows, "sd_dd0")
  sd_map <- .resolve_sd(sd_map, env$map_sd, rows, "sd_map")

  # Central prediction (also runs the usual diagnostics)
  central <- ung_volume(x$species, x$age, x$dd0, x$map, model = model, warn = warn)

  if (!is.null(seed)) {
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    if (had_seed) old_seed <- get(".Random.seed", envir = globalenv())
    on.exit({
      if (had_seed) assign(".Random.seed", old_seed, envir = globalenv())
      else rm(".Random.seed", envir = globalenv())
    }, add = TRUE)
    set.seed(seed)
  }

  # Draws: x2 is built from z1 and an independent z2 to give correlation `cor`
  idx <- rep(seq_len(rows), each = n)
  z1 <- stats::rnorm(rows * n)
  z2 <- stats::rnorm(rows * n)
  d <- x[idx, c("species", "age", "dd0", "map"), drop = FALSE]
  d$dd0 <- pmax(x$dd0[idx] + sd_dd0[idx] * z1, 0)
  d$map <- pmax(x$map[idx] + sd_map[idx] * (cor * z1 + sqrt(1 - cor^2) * z2), 0)
  pred <- .predict(d, model)
  outside <- d$dd0 < env$dd0_min[idx] | d$dd0 > env$dd0_max[idx] |
    d$map < env$map_min[idx] | d$map > env$map_max[idx]
  prop_outside <- colMeans(matrix(outside, nrow = n))

  probs <- c((1 - interval) / 2, 0.5, 1 - (1 - interval) / 2)
  cols <- switch(model,
    Nat1 = c(Nat1 = "V_Nat1"),
    Nat2 = c(Nat2 = "V_Nat2"),
    both = c(Nat1 = "V_Nat1", Nat2 = "V_Nat2")
  )
  res <- lapply(names(cols), function(m) {
    col <- cols[[m]]
    q <- apply(matrix(pred[[col]], nrow = n), 2, stats::quantile,
               probs = probs, names = FALSE, na.rm = TRUE)
    data.frame(
      row = seq_len(rows), x, sd_dd0 = sd_dd0, sd_map = sd_map, model = m,
      volume = central[[col]], median = q[2, ], lower = q[1, ], upper = q[3, ],
      prop_outside = prop_outside, stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, res)
  out <- out[order(out$row, out$model), ]
  rownames(out) <- NULL
  attr(out, "defaulted") <- NULL
  attr(out, "interval") <- interval
  attr(out, "n") <- n
  class(out) <- c("ung_uncertainty", "data.frame")
  out
}

# One SD per stand: NULL -> species default; otherwise validate and recycle.
.resolve_sd <- function(sd, default, rows, name) {
  if (is.null(sd)) return(default)
  if (!is.numeric(sd) || anyNA(sd) || any(sd < 0) || !(length(sd) %in% c(1L, rows))) {
    stop("`", name, "` must be NULL, or non-negative numbers of length 1 or ",
         "the number of stands.", call. = FALSE)
  }
  rep_len(as.numeric(sd), rows)
}

#' Plot a climate-uncertainty fan
#'
#' Draws the interval of predicted volume against age as a shaded band with the
#' median as a line, one colour per species/climate combination and one line
#' type per model.
#'
#' @param x An object returned by [ung_uncertainty()].
#' @param ... Passed to [graphics::plot()].
#' @return `x`, invisibly.
#' @export
#' @examples
#' f <- ung_uncertainty("white spruce", seq(20, 200, by = 20), dd0 = 1800,
#'                      map = 700, seed = 1, warn = FALSE)
#' plot(f)
plot.ung_uncertainty <- function(x, ...) {
  info <- .curve_groups(x)
  grp <- info$group
  levels_g <- info$levels
  colors <- grDevices::hcl.colors(max(length(levels_g), 2L), "Dark 3")
  models <- sort(unique(x$model))
  lab <- paste0(round(100 * attr(x, "interval")), "% interval")

  yr <- range(c(x$lower, x$upper), na.rm = TRUE, finite = TRUE)
  graphics::plot(range(x$age, na.rm = TRUE), yr, type = "n",
                 xlab = "Age (years)", ylab = "Volume (m3/ha)", ...)
  for (g in seq_along(levels_g)) {
    for (k in seq_along(models)) {
      d <- x[grp == levels_g[g] & x$model == models[k], , drop = FALSE]
      d <- d[order(d$age), , drop = FALSE]
      ok <- is.finite(d$lower) & is.finite(d$upper)
      if (sum(ok) > 1L) {
        d <- d[ok, , drop = FALSE]
        graphics::polygon(c(d$age, rev(d$age)), c(d$lower, rev(d$upper)),
                          col = grDevices::adjustcolor(colors[g], 0.25),
                          border = NA)
        graphics::lines(d$age, d$median, col = colors[g], lty = k, lwd = 2)
      }
    }
  }
  graphics::legend("topleft",
                   legend = c(info$labels, paste(models, "median"), lab),
                   col = c(colors[seq_along(levels_g)], rep("black", length(models)),
                           "grey60"),
                   lty = c(rep(1, length(levels_g)), seq_along(models), NA),
                   pch = c(rep(NA, length(levels_g) + length(models)), 15),
                   bty = "n", cex = 0.8)
  invisible(x)
}
