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