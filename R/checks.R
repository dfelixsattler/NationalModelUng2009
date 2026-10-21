# Thresholds for diagnostic warnings (documented in ?ung_volume)
.young_age <- 10          # years; below this, predictions are ~0 and unreliable
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

  # Climate: outside the fitting data; also the most common unit mix-up (DD5)
  out_dd0 <- x$dd0 < env$dd0_min | x$dd0 > env$dd0_max
  out_map <- x$map < env$map_min | x$map > env$map_max
  .warn_rows(out_dd0 | out_map, n,
             paste0("climate is outside the range of the fitting data ",
                    "(dd0 ", min(env$dd0_min), "-", max(env$dd0_max),
                    ", map ", min(env$map_min), "-", max(env$map_max),
                    " for the pooled range). Predictions are extrapolations. ",
                    "`dd0` must be degree-days above 0 C (not DD5) and `map` ",
                    "annual precipitation in mm. Pooled ranges are used for ",
                    "species other than black spruce, jack pine and ",
                    "trembling aspen."),
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

  # Outputs beyond anything in the fitting data
  vcols <- intersect(c("V_Nat1", "V_Nat2"), names(out))
  too_big <- Reduce(`|`, lapply(vcols, function(v) out[[v]] > .max_observed[["V"]]))
  if ("BA_Nat1" %in% names(out)) too_big <- too_big | out$BA_Nat1 > .max_observed[["BA"]]
  .warn_rows(too_big, n,
             paste0("predicted volume or basal area exceeds the largest value ",
                    "in the fitting data (", .max_observed[["V"]], " m3/ha, ",
                    .max_observed[["BA"]], " m2/ha)."),
             "ung2009_warning_output")

  invisible(NULL)
}
