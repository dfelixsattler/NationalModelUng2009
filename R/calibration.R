# Calibration envelope used to flag extrapolation: per-species minima and
# maxima of age, D0, P, H, G and V in the fitting data (see ?ung_envelope).
.envelope_for <- function(codes) {
  env <- NationalModelUng2009::ung_envelope
  env[match(codes, env$species), , drop = FALSE]
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
