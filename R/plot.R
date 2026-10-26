#' Plot predicted yield curves
#'
#' Draws predicted volume against age, one line per species/climate
#' combination and one line type per model.
#'
#' @param x An object returned by [ung_volume()].
#' @param what Variable to plot: `"V"` (volume, default), or `"H"` / `"G"`
#'   (Nat1 dominant height and basal area only).
#' @param ... Passed to [graphics::plot()].
#' @return `x`, invisibly.
#' @export
#' @examples
#' d <- ung_volume("white spruce", 5:200, dd0 = 1800, map = 700, warn = FALSE)
#' plot(d)
plot.ung_volume <- function(x, what = c("V", "H", "G"), ...) {
  what <- match.arg(what)
  cols <- switch(what,
    V = intersect(c("V_Nat1", "V_Nat2"), names(x)),
    H = intersect("H_Nat1", names(x)),
    G = intersect("G_Nat1", names(x))
  )
  if (length(cols) == 0L) {
    stop("`x` has no ", what, " predictions (check the `model` used).", call. = FALSE)
  }
  units <- c(V = "Volume V (m3/ha)", H = "Dominant height H (m)",
             G = "Basal area G (m2/ha)")[[what]]

  # One group per species x climate combination, labelled in plain words
  info <- .curve_groups(x)
  grp <- info$group
  levels_g <- info$levels
  colors <- grDevices::hcl.colors(max(length(levels_g), 2L), "Dark 3")

  graphics::plot(range(x$age, na.rm = TRUE),
                 range(unlist(x[cols]), na.rm = TRUE, finite = TRUE),
                 type = "n", xlab = "Age (years)", ylab = units, ...)
  for (g in seq_along(levels_g)) {
    d <- x[grp == levels_g[g], , drop = FALSE]
    d <- d[order(d$age), , drop = FALSE]
    for (k in seq_along(cols)) {
      graphics::lines(d$age, d[[cols[k]]], col = colors[g], lty = k, lwd = 2)
    }
  }
  graphics::legend("topleft",
                   legend = c(info$labels, sub("_", " ", cols)),
                   col = c(colors[seq_along(levels_g)], rep("black", length(cols))),
                   lty = c(rep(1, length(levels_g)), seq_along(cols)),
                   bty = "n", cex = 0.8)
  invisible(x)
}

# Group rows by species and climate. Returns the group of each row, the group
# keys (in order of appearance) and a readable label per key, such as
# "PICE.MAR (dd0 2231, map 1030)".
.curve_groups <- function(x) {
  key <- paste(x$species, x$dd0, x$map, sep = "|")
  keys <- unique(key)
  first <- match(keys, key)
  labels <- sprintf("%s (dd0 %s, map %s)", x$species[first],
                    round(x$dd0[first]), round(x$map[first]))
  list(group = key, levels = keys, labels = labels)
}

#' Plot a yield table
#'
#' Draws volume against age, one colour per curve (stand, species and
#' climate) and one line type per model. If the table has an uncertainty
#' interval (`uncertainty = TRUE`), it is drawn as a shaded band. To show
#' Nat1 and Nat2 together, combine two tables with [rbind()].
#'
#' @param x A long-format table from [ung_yield_table()].
#' @param ... Passed to [graphics::plot()].
#' @return `x`, invisibly.
#' @export
#' @examples
#' tab <- ung_yield_table(c("black spruce", "jack pine"), dd0 = 2194, map = 461)
#' plot(tab)
plot.ung_yield_table <- function(x, ...) {
  if (!all(c("age", "volume", "model") %in% names(x))) {
    stop("`x` must be a yield table made with format = \"long\".", call. = FALSE)
  }
  band <- all(c("lower", "upper") %in% names(x))
  key <- paste(if ("id" %in% names(x)) x$id else "", x$species, x$dd0, x$map,
               sep = "|")
  keys <- unique(key)
  first <- match(keys, key)
  labels <- sprintf("%s%s (dd0 %s, map %s)",
                    if ("id" %in% names(x)) paste0(x$id[first], " ") else "",
                    x$species[first], round(x$dd0[first]), round(x$map[first]))
  models <- unique(x$model)
  colors <- grDevices::hcl.colors(max(length(keys), 2L), "Dark 3")

  yr <- range(c(x$volume, if (band) c(x$lower, x$upper)), na.rm = TRUE,
              finite = TRUE)
  graphics::plot(range(x$age, na.rm = TRUE), yr, type = "n",
                 xlab = "Age (years)", ylab = "Volume (m3/ha)", ...)
  for (g in seq_along(keys)) {
    for (k in seq_along(models)) {
      d <- x[key == keys[g] & x$model == models[k], , drop = FALSE]
      if (nrow(d) == 0L) next
      d <- d[order(d$age), , drop = FALSE]
      if (band) {
        ok <- is.finite(d$lower) & is.finite(d$upper)
        graphics::polygon(c(d$age[ok], rev(d$age[ok])),
                          c(d$lower[ok], rev(d$upper[ok])),
                          col = grDevices::adjustcolor(colors[g], 0.2),
                          border = NA)
      }
      graphics::lines(d$age, d$volume, col = colors[g], lty = k, lwd = 2)
    }
  }
  graphics::legend("topleft",
                   legend = c(labels, if (length(models) > 1L) models),
                   col = c(colors[seq_along(keys)],
                           rep("black", if (length(models) > 1L) length(models) else 0L)),
                   lty = c(rep(1, length(keys)),
                           if (length(models) > 1L) seq_along(models)),
                   bty = "n", cex = 0.8)
  invisible(x)
}