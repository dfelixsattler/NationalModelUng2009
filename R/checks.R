#' Check predictions for extrapolation and other cautions
#'
#' Runs every check the package knows about on a set of predictions and
#' explains, in plain English, how many rows each one affects. [ung_volume()]
#' only warns about the checks marked *warns* below, because the others apply
#' to almost every yield curve and would otherwise appear every time.
#'
#' | Check | What it means | Warns |
#' | --- | --- | --- |
#' | `missing_input` | `age`, `dd0` or `map` is missing, so the prediction is `NA` | yes |
#' | `older_than_data` | the stand is older than any stand used to fit the species' model | yes |
#' | `climate_outside_data` | `dd0` or `map` is outside the climate of the species' fitting plots | yes |
#' | `output_beyond_data` | predicted volume or basal area is larger than in any fitting plot | yes |
#' | `young_age` | the stand is younger than 10 years or than any fitting plot; predictions are near zero and unreliable | no |
#' | `long_horizon` | one species and climate is predicted over more than 10 years of age (a yield curve); the models were designed for changes over less than 10 years | no |
#' | `sensitive_to_climate` | 100 degree-days or 100 mm more or less changes volume by more than 15 % (see [ung_sensitivity()]) | no |
#' | `models_disagree` | Nat1 and Nat2 volumes differ by more than 30 % | no |
#'
#' Age 0 rows are never flagged as young: they are set to 0 by definition.
#' The limits of 10 years, 15 % and 30 % are rules of thumb chosen for this
#' package; they are not from the paper. The fitting-data ranges are in
#' [ung_envelope].
#'
#' @param x A data.frame with columns `species`, `age`, `dd0` and `map`, such
#'   as the result of [ung_volume()], [ung_curve()], [ung_uncertainty()] or
#'   [ung_yield_table()] (long format).
#' @param rows Logical. `FALSE` (default) returns one line per check. `TRUE`
#'   returns one line per row of `x`, with a `TRUE`/`FALSE` column per check.
#'
#' @return With `rows = FALSE`, a data.frame with columns `check`,
#'   `rows_flagged`, `rows_total` and `meaning`. With `rows = TRUE`, the
#'   `species`, `age`, `dd0` and `map` of `x` followed by one logical column per
#'   check.
#' @seealso [ung_volume()], [ung_sensitivity()]
#' @export
#' @examples
#' curve <- ung_volume("jack pine", age = seq(0, 200, by = 10),
#'                     dd0 = 2200, map = 800)
#' ung_check(curve)
#'
#' # Which ages are affected?
#' flags <- ung_check(curve, rows = TRUE)
#' flags$age[flags$sensitive_to_climate]
ung_check <- function(x, rows = FALSE) {
  .check_logical(rows, "rows")
  if (!is.data.frame(x) || !all(c("species", "age", "dd0", "map") %in% names(x))) {
    stop("`x` must be a data.frame with columns `species`, `age`, `dd0` and ",
         "`map`, such as the result of ung_volume(). For ung_yield_table(), ",
         "use format = \"long\".", call. = FALSE)
  }
  # ung_uncertainty() has one row per stand and model: keep one per stand
  if ("model" %in% names(x)) x <- x[x$model == x$model[1], , drop = FALSE]

  correction <- isTRUE(attr(x, "nat1_bias_correction"))
  pred <- ung_volume(x$species, x$age, x$dd0, x$map, model = "both",
                     nat1_bias_correction = correction, warn = FALSE)
  flags <- .flag_rows(pred, sensitivity = TRUE)

  if (isTRUE(rows)) {
    out <- cbind(as.data.frame(pred)[c("species", "age", "dd0", "map")], flags)
    rownames(out) <- NULL
    return(out)
  }
  data.frame(
    check = names(flags),
    rows_flagged = vapply(flags, sum, integer(1)),
    rows_total = nrow(pred),
    meaning = unname(.check_text[names(flags)]),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
}

# Thresholds used by the checks (rules of thumb, not from the paper)
.young_age <- 10          # years; below this, predictions are ~0 and unreliable
.max_horizon <- 10        # years; the models were designed for changes shorter than this
.sens_threshold <- 15     # % volume change for +/-100 degree-days or mm
.model_gap <- 0.30        # relative Nat1 vs Nat2 disagreement

# Plain-English explanation of each check
.check_text <- c(
  missing_input = "age, dd0 or map is missing, so the prediction is NA.",
  older_than_data = paste(
    "the stand is older than any stand used to fit the model for this",
    "species; the prediction is an extrapolation."),
  climate_outside_data = paste(
    "dd0 or map is outside the climate of the plots used to fit the model for",
    "this species; the prediction is an extrapolation. Check that dd0 is",
    "degree-days above 0 C (not DD5, DD_0 or DDsub0) and that map is in mm."),
  output_beyond_data = paste(
    "predicted volume or basal area is larger than in any plot used to fit",
    "the model for this species."),
  young_age = paste(
    "the stand is younger than", .young_age, "years or younger than any stand",
    "used to fit the model; predictions are close to zero and not reliable."),
  long_horizon = paste(
    "the same species and climate are predicted over more than", .max_horizon,
    "years of age (a yield curve). The authors designed the models for changes",
    "over less than 10 years and advise caution for longer projections."),
  sensitive_to_climate = paste0(
    "100 degree-days or 100 mm more or less changes predicted volume by more ",
    "than ", .sens_threshold, " %; the result is only as good as the climate ",
    "values (see ung_sensitivity())."),
  models_disagree = paste0(
    "Nat1 and Nat2 volumes differ by more than ", .model_gap * 100, " %.")
)

# One TRUE/FALSE vector per check for a prediction from ung_volume().
# The sensitivity check re-runs the model, so it is skipped when not needed.
.flag_rows <- function(out, sensitivity = TRUE) {
  env <- .envelope_for(out$species)
  age <- out$age
  f <- list()

  f$missing_input <- is.na(age) | is.na(out$dd0) | is.na(out$map)
  f$older_than_data <- age > env$age_max
  f$climate_outside_data <- out$dd0 < env$dd0_min | out$dd0 > env$dd0_max |
    out$map < env$map_min | out$map > env$map_max

  too_big <- rep(FALSE, nrow(out))
  for (v in intersect(c("V_Nat1", "V_Nat2"), names(out))) {
    too_big <- too_big | out[[v]] > env$v_max
  }
  if ("G_Nat1" %in% names(out)) too_big <- too_big | out$G_Nat1 > env$g_max
  f$output_beyond_data <- too_big

  f$young_age <- age > 0 & (age < .young_age | age < env$age_min)

  # Same species and climate over a span of ages longer than the design horizon
  grp <- paste(out$species, out$dd0, out$map)
  span <- stats::ave(age, grp, FUN = function(a) {
    if (all(is.na(a))) NA_real_ else diff(range(a, na.rm = TRUE))
  })
  f$long_horizon <- span > .max_horizon

  if (sensitivity) {
    model <- .model_of(out)
    sens <- .sensitivity(as.data.frame(out)[c("species", "age", "dd0", "map")], model)
    hit <- unique(sens$row[which(sens$max_change_pct > .sens_threshold)])
    f$sensitive_to_climate <- seq_len(nrow(out)) %in% hit
  }

  if (all(c("V_Nat1", "V_Nat2") %in% names(out))) {
    gap <- abs(out$V_Nat1 / out$V_Nat2 - 1)
    gap[out$V_Nat2 < 1] <- NA
    f$models_disagree <- gap > .model_gap
  }

  lapply(f, function(v) {
    v[is.na(v)] <- FALSE
    v
  })
}

# Which model(s) a prediction holds.
.model_of <- function(out) {
  has <- c(Nat1 = "V_Nat1" %in% names(out), Nat2 = "V_Nat2" %in% names(out))
  if (all(has)) "both" else names(has)[has]
}

# Issue at most one warning, listing only the checks the user can act on.
.warn_summary <- function(out) {
  keys <- c("missing_input", "older_than_data", "climate_outside_data",
            "output_beyond_data")
  flags <- .flag_rows(out, sensitivity = FALSE)[keys]
  n <- vapply(flags, sum, integer(1))
  if (any(n > 0L)) {
    lines <- sprintf("* %d of %d row(s): %s", n[n > 0L], nrow(out),
                     .check_text[keys][n > 0L])
    .ung_warn(paste0("Some predictions need care:\n",
                     paste(lines, collapse = "\n"),
                     "\nRun ung_check() on the result for these and other checks."))
  }
  invisible(NULL)
}
