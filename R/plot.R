#' Plot predicted yield curves
#'
#' Draws predicted volume against age, one line per species/climate
#' combination and one line type per model.
#'
#' @param x An object returned by [ung_volume()].
#' @param what Variable to plot: `"V"` (volume, default), or `"H"` / `"BA"`
#'   (Nat1 height and basal area only).
#' @param ... Passed to [graphics::plot()].
#' @return `x`, invisibly.
#' @export
#' @examples
#' d <- ung_volume("white spruce", 5:200, dd0 = 1800, map = 700, warn = FALSE)
#' plot(d)
plot.ung_volume <- function(x, what = c("V", "H", "BA"), ...) {
  what <- match.arg(what)
  cols <- switch(what,
    V = intersect(c("V_Nat1", "V_Nat2"), names(x)),
    H = intersect("H_Nat1", names(x)),
    BA = intersect("BA_Nat1", names(x))
  )
  if (length(cols) == 0L) {
    stop("`x` has no ", what, " predictions (check the `model` used).", call. = FALSE)
  }
  units <- c(V = "Volume (m3/ha)", H = "Height (m)", BA = "Basal area (m2/ha)")[[what]]

  # One group per species x climate combination
  grp <- interaction(x$species, x$dd0, x$map, drop = TRUE)
  levels_g <- levels(grp)
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
  graphics::legend("topleft", legend = c(levels_g, sub("_", " ", cols)),
                   col = c(colors[seq_along(levels_g)], rep("black", length(cols))),
                   lty = c(rep(1, length(levels_g)), seq_along(cols)),
                   bty = "n", cex = 0.8, title = "species.dd0.map")
  invisible(x)
}
