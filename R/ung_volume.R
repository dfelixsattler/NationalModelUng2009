#' Predict stand volume with the Ung et al. (2009) national models
#'
#' Applies the two national growth-and-yield models of Ung et al. (2009) to
#' one or many stands. Both models are empirical, climate-based alternatives to
#' site-index driven yield curves:
#'
#' * **Nat1** predicts dominant height `H` (m), basal area `BA` (m2/ha) and,
#'   from those, gross merchantable volume `V` (m3/ha). Height and basal area
#'   follow a simplified Chapman-Richards form,
#'   `ln(H) = h1 + h2 / age` and `ln(BA) = g1 + g2 / age`, where each of
#'   `h1, h2, g1, g2` is a linear function of `dd0` and `map`
#'   (e.g. `h1 = h10 + h11 * dd0 + h12 * map`). Volume is
#'   `ln(V) = v1 + v2 * ln(H) + v3 * ln(BA)`. All three equations are
#'   back-transformed with the Duan (1983) smearing correction factor.
#' * **Nat2** predicts volume `V2` directly,
#'   `ln(V) = v1 + v2 / age`, with `v1` and `v2` linear in `dd0` and `map`,
#'   again back-transformed with a Duan correction factor.
#'
#' @section Intended use and time horizon:
#' The authors state (Ung et al. 2009, Discussion): "the models developed here
#' were designed for increment predictions over very short (< 10 years)
#' intervals, as requested within the context of the CNFI. The absence of
#' safeguards, such as an empirical adjustment to the number of merchantable
#' stems per hectare, means that the user who may want to use these models for
#' longer-term projections should use caution."
#'
#' (CNFI is the Canadian National Forest Inventory.) A yield curve over many
#' decades, such as the one drawn by `plot()`, is a longer-term projection in
#' this sense. [ung_volume()] therefore warns (class `ung2009_warning_horizon`)
#' when one call predicts the same species and climate over ages that span more
#' than 10 years.
#'
#' @section Climate inputs:
#' * `dd0` is **annual degree-days above 0 degrees C** (the paper's `D0`). It is
#'   *not* growing degree-days above 5 degrees C (`DD5`), and it is *not*
#'   ClimateNA/ClimateBC/climr `DD_0`, which is degree-days *below* 0 degrees C.
#'   Using either gives silently wrong answers.
#' * `map` is **annual precipitation in mm** (`MAP`; the paper's `P`).
#' * Supply **one value of each per stand**, held constant over the stand's age:
#'   the paper attached a single plot-level `D0` and `P` to every plot and, when
#'   predicting increments, used the same values at both measurement dates. They
#'   are per-year quantities (degree-days per year, mm per year), not a time
#'   series. The paper derived them from interpolated climate normals "to which
#'   inter-annual variability has been restored" (McKenney et al. 2001) and does
#'   not state the averaging period, so use values representative of the stand
#'   location over several decades (e.g. 1981-2010 normals, which is what
#'   [ung_climate()] returns) and report which you used.
#'
#' @section Warnings:
#' With `warn = TRUE` (the default) the function warns, once per issue and with
#' the number of affected rows, when:
#' * **age** is under 10 years (predictions are near zero and unreliable) or
#'   outside the age range of the fitting data (class `ung2009_warning_age`);
#' * **time horizon**: ages for the same species and climate span more than 10
#'   years, so the result is a longer-term projection than the models were
#'   designed for (class `ung2009_warning_horizon`; see *Intended use and time
#'   horizon*);
#' * **climate** is outside the range of the fitting data for that species
#'   (class `ung2009_warning_climate`; ranges in [ung_envelope]);
#' * **sensitivity**: a change of 100 degree-days or 100 mm precipitation
#'   changes predicted volume by more than 15 %
#'   (class `ung2009_warning_sensitivity`; see [ung_sensitivity()]). The climate
#'   terms are applied to both the asymptote and the age-rate parameters, so
#'   predictions can change sharply, and not always monotonically, with small
#'   climate differences;
#' * **model disagreement**: Nat1 and Nat2 volumes differ by more than 30 %
#'   (class `ung2009_warning_models`);
#' * **implausible output**: volume or basal area exceeds the largest value in
#'   the fitting data (class `ung2009_warning_output`);
#' * **missing values** in the inputs give `NA` predictions
#'   (class `ung2009_warning_na`).
#'
#' All classes also inherit from `ung2009_warning`, so
#' `withCallingHandlers()` or `suppressWarnings(classes = "ung2009_warning_climate")`
#' can silence individual checks.
#'
#' @section Limitations stated by the authors:
#' * The models were built for **increment predictions over very short (< 10
#'   years) intervals** within the CNFI, with no safeguard on the number of
#'   merchantable stems per hectare. Use long-term projections with caution
#'   (see *Intended use and time horizon*).
#' * They were fitted to **single-measurement temporary plots** with one
#'   species making up at least 75 % of basal area. For mixed stands the
#'   authors suggest applying the model to each species separately.
#' * The climate terms are **descriptive, not predictive of climate change**.
#'   Sampling was biased away from extreme climates, so do not feed future
#'   climate projections into these equations and interpret the result as a
#'   climate-change impact.
#' * Predictive ability for increments was rated moderate to poor, comparable
#'   with provincial models.
#'
#' @param species Character vector. Species code, scientific name or common name
#'   (case-insensitive); see [ung_species()].
#' @param age Numeric vector. Stand age in years (> 0).
#' @param dd0 Numeric vector. Annual degree-days above 0 degrees C (not DD5).
#'   If `NULL` (default), the average `dd0` of the plots used to fit that
#'   species' model is used (column `dd0_mean` of [ung_envelope]); see
#'   *Climate used when `dd0` and `map` are omitted*.
#' @param map Numeric vector. Mean annual precipitation in mm. If `NULL`
#'   (default), the average `map` of the plots used to fit that species' model
#'   is used (column `map_mean` of [ung_envelope]).
#' @param model One of `"both"` (default), `"Nat1"` or `"Nat2"`.
#' @param warn Logical. Set to `FALSE` to skip all diagnostic warnings and the
#'   message about default climate.
#'
#' @details Arguments are matched **row by row** and recycled: each must have
#'   length 1 or the same length as the longest. Species 1 is paired with age
#'   1, species 2 with age 2, and so on. To predict several species over a range
#'   of ages, use [ung_curve()], which combines every species with every age.
#'
#' @section Climate used when `dd0` and `map` are omitted:
#' The authors fitted each species' model to a set of measured field plots (the
#' "fitting plots"). Each plot has a `dd0` and a `map`. If you leave out `dd0`,
#' `map` or both, the package uses, for each species, the **average** `dd0` and
#' the **average** `map` of that species' fitting plots. These averages are
#' stored in [ung_envelope] (columns `dd0_mean` and `map_mean`). A message
#' states which values were substituted, and the values are returned in the
#' `dd0` and `map` columns of the result.
#'
#' Because the averages differ between species, two species are predicted under
#' two different climates. For example, black spruce uses 2079 degree-days and
#' 965 mm, and Douglas-fir uses 2352 degree-days and 727 mm. Volume still
#' depends on climate in the usual way.
#'
#' The result is a prediction for a **typical stand of each species**, not for
#' any particular site. It is useful for comparing species or sketching a
#' curve. For a real stand, supply the climate of its location (see
#' [ung_climate()]), and use [ung_uncertainty()] or [ung_sensitivity()] to see
#' how much the climate values matter.
#'
#' @return A data.frame of class `ung_volume` with one row per input row:
#'   `species` (code), `age`, `dd0`, `map` and, depending on `model`,
#'   `H_Nat1` (m), `BA_Nat1` (m2/ha), `V_Nat1` (m3/ha) and `V_Nat2` (m3/ha).
#'   Volume is gross volume of live merchantable trees (dbh > 9 cm).
#'
#' @references
#' Ung, C.-H., Bernier, P.Y., Guo, X.J. and Lambert, M.-C. 2009. A simple
#' growth and yield model for assessing changes in standing volume across
#' Canada's forests. The Forestry Chronicle 85(1): 57-64.
#' \doi{10.5558/tfc85057-1}
#'
#' Duan, N. 1983. Smearing estimate: a nonparametric retransformation method.
#' Journal of the American Statistical Association 78: 605-610.
#'
#' @seealso [ung_sensitivity()], [ung_uncertainty()], [ung_climate()],
#'   [ung_species()]
#' @export
#' @examples
#' # A typical stand of each species at age 80. `dd0` and `map` are omitted, so
#' # each species uses the average climate of the plots used to fit its model
#' # (shown in the dd0 and map columns of the result)
#' ung_volume(c("black spruce", "Douglas-fir"), age = 80)
#'
#' # Yield curves for two species: ung_curve() combines every species with every age
#' plot(ung_curve(c("black spruce", "Douglas-fir"), age = 10:150, warn = FALSE))
#'
#' # Trembling aspen yield curve for a boreal site
#' curve <- ung_volume("trembling aspen", age = seq(10, 150, by = 10),
#'                     dd0 = 2200, map = 750)
#' head(curve)
#'
#' # Several stands at once
#' stands <- data.frame(species = c("PICE.MAR", "PINU.BAN"),
#'                      age = c(80, 60), dd0 = c(2000, 2300), map = c(900, 700))
#' ung_volume(stands$species, stands$age, stands$dd0, stands$map, model = "Nat2")
ung_volume <- function(species, age, dd0 = NULL, map = NULL,
                       model = c("both", "Nat1", "Nat2"),
                       warn = TRUE) {
  model <- match.arg(model)

  # Validate and recycle inputs, then predict
  x <- .prepare_inputs(species, age, dd0, map)
  if (isTRUE(warn)) .note_defaults(x)
  out <- cbind(x, .predict(x, model))

  # Diagnostics on the predictions
  if (isTRUE(warn)) .check_prediction(x, out, model)

  class(out) <- c("ung_volume", "data.frame")
  out
}

# Validate inputs, resolve species names and recycle to a common length.
# NULL `dd0` / `map` are filled with the average of the plots used to fit each
# species' model and recorded in the "defaulted" attribute.
.prepare_inputs <- function(species, age, dd0 = NULL, map = NULL) {
  codes <- .resolve_species(species)

  defaulted <- character()
  env <- .envelope_for(codes)
  if (is.null(dd0)) {
    dd0 <- env$dd0_mean
    defaulted <- c(defaulted, "dd0")
  }
  if (is.null(map)) {
    map <- env$map_mean
    defaulted <- c(defaulted, "map")
  }

  # A bare NA is logical; treat it as a missing number
  age <- if (is.logical(age) && all(is.na(age))) as.numeric(age) else age
  dd0 <- if (is.logical(dd0) && all(is.na(dd0))) as.numeric(dd0) else dd0
  map <- if (is.logical(map) && all(is.na(map))) as.numeric(map) else map

  nums <- list(age = age, dd0 = dd0, map = map)
  for (nm in names(nums)) {
    v <- nums[[nm]]
    if (!is.numeric(v) || length(v) == 0L) {
      stop("`", nm, "` must be a non-empty numeric vector.", call. = FALSE)
    }
    if (any(is.infinite(v))) stop("`", nm, "` must be finite.", call. = FALSE)
  }

  n <- max(length(codes), lengths(nums))
  if (any(c(length(codes), lengths(nums)) %nin% c(1L, n))) {
    stop("`species`, `age`, `dd0` and `map` must have length 1 or the same length. ",
         "Values are matched row by row. To predict several species over a ",
         "range of ages, use `ung_curve()`.",
         call. = FALSE)
  }

  if (any(age <= 0, na.rm = TRUE)) stop("`age` must be greater than 0.", call. = FALSE)
  if (any(dd0 < 0, na.rm = TRUE)) stop("`dd0` (degree-days) cannot be negative.", call. = FALSE)
  if (any(map < 0, na.rm = TRUE)) stop("`map` (precipitation) cannot be negative.", call. = FALSE)

  out <- data.frame(
    species = rep_len(codes, n),
    age = rep_len(as.numeric(age), n),
    dd0 = rep_len(as.numeric(dd0), n),
    map = rep_len(as.numeric(map), n),
    stringsAsFactors = FALSE
  )
  attr(out, "defaulted") <- defaulted
  out
}

# Tell the user when species-mean climate was substituted.
.note_defaults <- function(x) {
  d <- attr(x, "defaulted")
  if (length(d) > 0L) {
    message(paste0("`", d, "`", collapse = " and "),
            if (length(d) > 1L) " were" else " was", " not supplied. Using, ",
            "for each species, the average ", paste(d, collapse = " and "),
            " of the plots used to fit that species' model (see ?ung_envelope). ",
            "The result is for a typical stand of each species, not for a ",
            "specific site.")
  }
  invisible(x)
}

`%nin%` <- function(x, table) !(x %in% table)

# Core equations (vectorised over rows of `x`, one parameter row per stand).
.predict <- function(x, model) {
  p <- NationalModelUng2009::ung_parameters
  p <- p[match(x$species, p$species), , drop = FALSE]
  out <- list()

  if (model %in% c("Nat1", "both")) {
    # Height and basal area: parameters are linear in climate, rate term is / age
    ln_h <- (p$h10 + p$h11 * x$dd0 + p$h12 * x$map) +
      (p$h20 + p$h21 * x$dd0 + p$h22 * x$map) / x$age
    ln_g <- (p$g10 + p$g11 * x$dd0 + p$g12 * x$map) +
      (p$g20 + p$g21 * x$dd0 + p$g22 * x$map) / x$age

    # Volume uses the *uncorrected* ln(H) and ln(BA); Duan factors apply on output
    # (authors' "system equations.xls": ln(V) = v30 + v31*ln(H) + v32*ln(G))
    ln_v <- p$v30 + p$v31 * ln_h + p$v32 * ln_g

    out$H_Nat1 <- exp(ln_h) * p$CDh
    out$BA_Nat1 <- exp(ln_g) * p$CDg
    out$V_Nat1 <- exp(ln_v) * p$CDv
  }

  if (model %in% c("Nat2", "both")) {
    ln_v2 <- (p$v10 + p$v11 * x$dd0 + p$v12 * x$map) +
      (p$v20 + p$v21 * x$dd0 + p$v22 * x$map) / x$age
    out$V_Nat2 <- exp(ln_v2) * p$CDv2
  }

  as.data.frame(out)
}
