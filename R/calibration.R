# Calibration envelope used to flag extrapolation.
# Source: Table 2 of Ung et al. (2009), which reports min/max of the fitting
# data for black spruce, jack pine and trembling aspen only. For the other 22
# species no ranges are published, so the pooled range of those three species
# is used as an approximate envelope (and the warning says so).
.calibration_envelope <- function() {
  data.frame(
    code    = c("PICE.MAR", "PINU.BAN", "POPU.TRE", NA),
    age_min = c(7.0,   4.0,   6.0,   4.0),
    age_max = c(215.9, 159.0, 161.0, 215.9),
    dd0_min = c(1252,  1437,  1304,  1252),
    dd0_max = c(2869,  2753,  3139,  3139),
    map_min = c(248,   416,   235,   235),
    map_max = c(1739,  1462,  1612,  1739),
    stringsAsFactors = FALSE
  )
}

# Largest plot values in the fitting data (Table 2, pooled): volume m3/ha and
# basal area m2/ha. Predictions beyond these are flagged as implausible.
.max_observed <- c(V = 802.6, BA = 93.0)

# Row-wise envelope for a vector of species codes (NA row = pooled default).
.envelope_for <- function(codes) {
  env <- .calibration_envelope()
  idx <- match(codes, env$code)
  idx[is.na(idx)] <- nrow(env)
  out <- env[idx, , drop = FALSE]
  out$specific <- codes %in% env$code[!is.na(env$code)]
  out
}

# Emit one aggregated warning with a custom class so users can filter it with
# suppressWarnings()/withCallingHandlers() (e.g. class = "ung2009_warning_climate").
.ung_warn <- function(msg, class) {
  warning(warningCondition(msg, class = c(class, "ung2009_warning")))
}

# Warn about rows where `flag` is TRUE, reporting how many and an example.
.warn_rows <- function(flag, n, text, class) {
  flag[is.na(flag)] <- FALSE
  if (any(flag)) {
    .ung_warn(sprintf("%d of %d row(s): %s", sum(flag), n, text), class)
  }
  invisible(NULL)
}
