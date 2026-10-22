# Fitting-data envelope used to flag extrapolation: per-species minima and
# maxima of age, dd0, map, H, G and V in the fitting data (see ?ung_envelope).
.envelope_for <- function(codes) {
  env <- NationalModelUng2009::ung_envelope
  env[match(codes, env$species), , drop = FALSE]
}

# Emit a warning of class "ung2009_warning", so users can catch or silence it
# with withCallingHandlers() or suppressWarnings(classes = "ung2009_warning").
.ung_warn <- function(msg) {
  warning(warningCondition(msg, class = "ung2009_warning"))
}
