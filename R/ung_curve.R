# Predict every species at every age (all ages of species 1, then species 2,
# and so on). Used by ung_yield_table().
.ung_curve <- function(species, age, dd0 = NULL, map = NULL,
                      model = c("both", "Nat1", "Nat2"),
                      nat1_bias_correction = FALSE, warn = TRUE) {
  model <- match.arg(model)
  codes <- .resolve_species(species)
  ns <- length(codes)

  per_species <- function(v, nm) {
    if (is.null(v)) return(NULL)
    if (!is.numeric(v) || !length(v) %in% c(1L, ns)) {
      stop("`", nm, "` must be NULL, one value, or one value per species.",
           call. = FALSE)
    }
    rep_len(v, ns)
  }
  dd0 <- per_species(dd0, "dd0")
  map <- per_species(map, "map")

  if (!is.numeric(age) || length(age) == 0L) {
    stop("`age` must be a non-empty numeric vector.", call. = FALSE)
  }
  s <- rep(seq_len(ns), each = length(age))

  ung_volume(codes[s], rep(age, times = ns),
             dd0 = if (is.null(dd0)) NULL else dd0[s],
             map = if (is.null(map)) NULL else map[s],
             model = model, nat1_bias_correction = nat1_bias_correction,
             warn = warn)
}
