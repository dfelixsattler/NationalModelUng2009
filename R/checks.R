# Thresholds for diagnostic warnings (documented in ?ung_volume)
.young_age <- 10          # years; below this, predictions are ~0 and unreliable
.max_horizon <- 10        # years; the models were designed for increments shorter than this
.sens_threshold <- 15     # % volume change for +/-100 degree-days or mm
.model_gap <- 0.30        # relative Nat1 vs Nat2 disagreement

# Run all diagnostics on a set of predictions. `x` holds the prepared inputs
# and `out` the inputs plus predictions.
.check_prediction <- function(x, out, model) {
  n <- nrow(x)
  env <- .envelope_for(x$species)

  # Missing inputs propagate to NA predictions
  .warn_rows(is.na(x$age) | is.na(x$dd0) | is.na(x$map), n,
             "missing `age`, `dd0` or `map`; predictions are NA.",
             "ung2009_warning_na")

  # Age: too young, or outside the fitting data
  .warn_rows(x$age < .young_age, n,
             paste0("age < ", .young_age, " years; predicted volume is near ",
                    "zero and not reliable."),
             "ung2009_warning_age")
  .warn_rows(x$age >= .young_age & (x$age < env$age_min | x$age > env$age_max), n,
             "age is outside the range of the fitting data (see ?ung_volume).",
             "ung2009_warning_age")

  # Horizon: the same species and climate predicted over a span of ages longer
  # than the models were designed for (a yield curve or long-term projection)
  grp <- paste(x$species, x$dd0, x$map)
  span <- stats::ave(x$age, grp, FUN = function(a) {
    if (all(is.na(a))) NA_real_ else diff(range(a, na.rm = TRUE))
  })
  .warn_rows(span > .max_horizon, n,
             paste0("ages for the same species and climate span more than ",
                    .max_horizon, " years. The models were designed for ",
                    "increment predictions over very short (< ", .max_horizon,
                    " years) intervals and have no safeguard such as an ",
                    "adjustment to the number of merchantable stems per ",
                    "hectare, so use caution for longer-term projections ",
                    "(see ?ung_volume)."),
             "ung2009_warning_horizon")

  # Climate: outside the fitting data for the species; also the most common
  # unit mix-up (DD5, or DD_0 which is degree-days *below* 0)
  out_dd0 <- x$dd0 < env$dd0_min | x$dd0 > env$dd0_max
  out_map <- x$map < env$map_min | x$map > env$map_max
  .warn_rows(out_dd0 | out_map, n,
             paste0("climate is outside the range of the fitting data for the ",
                    "species (see ?ung_envelope). Predictions are ",
                    "extrapolations. `dd0` must be degree-days above 0 C (not ",
                    "DD5 or DD_0) and `map` annual precipitation in mm."),
             "ung2009_warning_climate")

  # Sensitivity to small climate changes
  sens <- .sensitivity(x, model)
  sensitive_rows <- unique(sens$row[which(sens$max_change_pct > .sens_threshold)])
  .warn_rows(seq_len(n) %in% sensitive_rows, n,
             paste0("volume changes by more than ", .sens_threshold, "% for ",
                    "a 100 degree-day or 100 mm change in climate; treat the ",
                    "result as uncertain (see ung_sensitivity())."),
             "ung2009_warning_sensitivity")

  # Nat1 and Nat2 should be close; large gaps signal poor local behaviour
  if (model == "both") {
    gap <- abs(out$V_Nat1 / out$V_Nat2 - 1)
    gap[out$V_Nat2 < 1] <- NA
    .warn_rows(gap > .model_gap, n,
               paste0("Nat1 and Nat2 volumes differ by more than ",
                      .model_gap * 100, "%."),
               "ung2009_warning_models")
  }

  # Outputs beyond anything in the fitting data for the species
  vcols <- intersect(c("V_Nat1", "V_Nat2"), names(out))
  too_big <- Reduce(`|`, lapply(vcols, function(v) out[[v]] > env$v_max))
  if ("BA_Nat1" %in% names(out)) too_big <- too_big | out$BA_Nat1 > env$ba_max
  .warn_rows(too_big, n,
             paste0("predicted volume or basal area exceeds the largest value ",
                    "in the fitting data for the species (see ?ung_envelope)."),
             "ung2009_warning_output")

  invisible(NULL)
}
