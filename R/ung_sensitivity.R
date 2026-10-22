#' Sensitivity of predicted volume to small changes in climate
#'
#' **Purpose.** Climate values for a site are never exact: different climate
#' sources, or different averaging periods, give different `dd0` and `map`. This
#' function answers the question "if my `dd0` is wrong by 100 degree-days, or my
#' `map` by 100 mm, how much does the predicted volume change?" A large
#' percentage means the prediction is only as good as the climate values, and
#' the result should be read with caution.
#'
#' The Ung et al. (2009) parameters make predicted volume respond strongly, and
#' sometimes in opposite directions, to modest differences in the climate
#' inputs. This function re-runs the model with
#' `dd0 +/- d_dd0` and `map +/- d_map` and reports the largest relative
#' change in volume. [ung_check()] uses it to flag predictions whose change
#' exceeds 15 % (a rule of thumb, not a value from the paper). The percentage
#' depends on the species and the age, not on the climate values themselves.
#'
#' Percent changes are `NA` where predicted volume is below 1 m3/ha, because a
#' relative change is not meaningful for a near-empty stand.
#'
#' @inheritParams ung_volume
#' @param d_dd0 Perturbation applied to `dd0` (degree-days). Default 100.
#' @param d_map Perturbation applied to `map` (mm). Default 100.
#'
#' @return A data.frame with one row per input row and model: `row` (input row
#'   number), `species`, `age`, `dd0`, `map`, `model` (Nat1 or Nat2), `volume`
#'   (m3/ha at the supplied climate), `dd0_change_pct` (largest % change in
#'   volume when `dd0` is raised or lowered by `d_dd0`), `map_change_pct` (the
#'   same for `map` and `d_map`) and `max_change_pct` (the larger of the two).
#' @seealso [ung_volume()]
#' @export
#' @examples
#' ung_sensitivity(c("PINU.BAN", "ACER.SAC"), age = 80, dd0 = 2200, map = 800)
ung_sensitivity <- function(species, age, dd0 = NULL, map = NULL,
                            model = c("both", "Nat1", "Nat2"),
                            d_dd0 = 100, d_map = 100) {
  model <- match.arg(model)
  x <- .prepare_inputs(species, age, dd0, map)
  .note_defaults(x)
  .sensitivity(x, model, d_dd0, d_map)
}

# Relative change in volume for climate perturbations (see ung_sensitivity()).
.sensitivity <- function(x, model, d_dd0 = 100, d_map = 100) {
  base <- .predict(x, model)

  # Largest absolute relative change of `col` across a +/- perturbation
  max_change <- function(dd0_shift, map_shift, col) {
    shifted <- function(s) {
      y <- x
      y$dd0 <- pmax(y$dd0 + s * dd0_shift, 0)
      y$map <- pmax(y$map + s * map_shift, 0)
      .predict(y, model)[[col]]
    }
    b <- base[[col]]
    ch <- pmax(abs(shifted(1) / b - 1), abs(shifted(-1) / b - 1))
    ifelse(b < 1, NA_real_, 100 * ch)
  }

  cols <- switch(model,
    Nat1 = c(Nat1 = "V_Nat1"),
    Nat2 = c(Nat2 = "V_Nat2"),
    both = c(Nat1 = "V_Nat1", Nat2 = "V_Nat2")
  )

  res <- lapply(names(cols), function(m) {
    col <- cols[[m]]
    d <- max_change(d_dd0, 0, col)
    p <- max_change(0, d_map, col)
    data.frame(
      row = seq_len(nrow(x)), x, model = m, volume = base[[col]],
      dd0_change_pct = d, map_change_pct = p,
      max_change_pct = pmax(d, p, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, res)
  out[order(out$row, out$model), ]
}
