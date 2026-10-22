#' Predict stand volume with the Ung et al. (2009) national models
#'
#' Predicts gross merchantable volume (m3/ha) for one or many stands from the
#' stand's age and two climate values, using the two national growth-and-yield
#' models of Ung et al. (2009).
#'
#' * **Nat1** first predicts dominant height `H` (m) and basal area `G`
#'   (m2/ha), then predicts volume from them:
#'   `ln(H) = h1 + h2 / age`, `ln(G) = g1 + g2 / age` and
#'   `ln(V) = v30 + v31 * ln(H) + v32 * ln(G)`. Each of `h1`, `h2`, `g1` and
#'   `g2` changes in a straight line with `dd0` and `map` (for example
#'   `h1 = h10 + h11 * dd0 + h12 * map`).
#' * **Nat2** predicts volume directly: `ln(V) = v1 + v2 / age`, where `v1`
#'   and `v2` are again straight-line functions of `dd0` and `map`.
#'
#' Volume is the gross volume of live merchantable trees, that is, trees with a
#' diameter at breast height greater than 9 cm.
#'
#' @section Which model to use:
#' For a single volume curve, for example for the Carbon Budget Model, use
#' **Nat2** (the default of [ung_yield_table()]). It predicts average volume
#' directly with its own correction factor, and its parameters are less affected
#' by rounding (see *Parameters are rounded*). Use **Nat1** when you also need
#' height and basal area, and read *Nat1 volume is biased low*.
#'
#' @section Climate inputs:
#' The models need two climate values for each stand:
#' * `dd0`: **degree-days above 0 degrees C** in a year (the paper's `D0`). Add
#'   up, over every day of the year, how far the day's mean temperature is
#'   above 0 degrees C (days below 0 count as zero). A value of 2000 means, for
#'   example, 200 days averaging 10 degrees C.
#' * `map`: **mean annual precipitation** in mm (the paper's `P`).
#'
#' Climate software uses similar-looking names for different things. Only the
#' first row of this table is the `dd0` the models need:
#'
#' | Name | Where you see it | What it measures | Use as `dd0`? |
#' | --- | --- | --- | --- |
#' | `dd0`, `D0` | this package, the paper | degree-days **above** 0 degrees C | **Yes** |
#' | `DD5`, `GDD` | ClimateNA, climr, many others | degree-days above **5** degrees C (growing degree-days) | No: too small |
#' | `DD_0` | ClimateNA, ClimateBC | degree-days **below** 0 degrees C (how cold the winter is) | No: the opposite quantity |
#' | `DDsub0` | climr | the same as `DD_0` (below 0 degrees C) | No: the opposite quantity |
#' | `DD18`, `DD_18`, `DDsub18` | ClimateNA, climr | degree-days above / below 18 degrees C | Only through [ung_climate()] or [ung_climate_from_climatena()], which combine them with `DD_0` to calculate `dd0` |
#'
#' Neither ClimateNA nor climr reports degree-days above 0 degrees C directly,
#' which is why the package calculates it for you.
#'
#' **One value per stand, for a long period.** Give one `dd0` and one `map`
#' per stand and keep them the same at every age: they describe the place, not
#' a particular year. The paper says each plot's climate came from
#' "interpolated climate normals to which inter-annual variability has been
#' restored" (McKenney et al. 2001), and does not explain this further. Our
#' reading is that the authors started from maps of long-term average climate
#' (built from weather-station records) and then added back the year-to-year
#' ups and downs that averaging removes. The paper does not say which years
#' were used. Use a long-term average for the stand's location (for example
#' 1981-2010 normals, which is what [ung_climate()] returns) and report which
#' period you used.
#'
#' @section Duan correction factor, in plain words:
#' The authors fitted each equation to the logarithm of the measured value
#' (log of height, of basal area, of volume). Converting a prediction back with
#' `exp()` gives about the *middle* (median) stand, which is lower than the
#' *average* stand: stands that grow better than expected add more volume than
#' poorer stands take away. Duan's (1983) "smearing" correction factor is a
#' number a little above 1, worked out by the authors from the scatter of their
#' data around each equation, that is multiplied onto the converted value so
#' that it estimates the average. More scatter gives a larger factor: for black
#' spruce it is 1.02 for height, 1.32 for basal area, 1.001 for Nat1 volume and
#' 1.15 for Nat2 volume.
#'
#' @section How Nat1 calculates volume:
#' The Nat1 volume equation is given the predicted *logarithms* of height and
#' basal area, before their Duan factors are applied. It is not given the
#' logarithms of the reported `H_Nat1` and `G_Nat1`, which already include
#' their Duan factors. This is how the authors fitted and wrote the system (in
#' their file `system equations.xls`) and is what the earlier R scripts do. It
#' is important: using the corrected height and basal area instead would raise
#' volume by `CDh^v31 * CDg^v32`, about a third for black spruce.
#'
#' @section Nat1 volume is biased low:
#' Nat1's volume correction factor (`CDv`, about 1.001) only covers the scatter
#' of the volume equation when height and basal area are *measured*. In Nat1
#' they are *predicted*, and their much larger scatter (basal-area factors of
#' 1.1 to 1.6) is carried into volume without any correction. Uncorrected Nat1
#' volume therefore estimates something closer to the middle stand than the
#' average stand, and is biased low. Across the 25 species, at age 80 and each
#' species' average climate, Nat2 volume is a median of about 20 % higher than
#' uncorrected Nat1 volume.
#'
#' Set `nat1_bias_correction = TRUE` to multiply Nat1 volume by a second-order
#' Taylor-series correction, `1 + s2 / 2`. Here
#' `s2 = v31^2 * 2 * ln(CDh) + v32^2 * 2 * ln(CDg)` is the variance that
#' height and basal-area errors add to `ln(V)`. Each variance is estimated from
#' its Duan factor (assuming the log-scale errors are roughly normal), and the
#' height and basal-area errors are assumed to be **uncorrelated**, because the
#' authors did not publish their correlation. The correction ranges from about
#' 1.05 to 1.46 among species (1.29 for black spruce). With it, the median gap
#' between Nat2 and Nat1 at age 80 shrinks from about 20 % to under 1 %, which
#' supports this explanation of the gap. It was added by the package author and is not
#' part of the published model, so it is off by default. Height and basal area
#' are not changed by it.
#'
#' @section Parameters are rounded to 4 decimal places:
#' The paper and every file supplied by the authors give the parameters to 4
#' decimal places (a few large values to 4 significant digits). The unrounded
#' values are not available, so the package uses the rounded ones. This
#' matters because some coefficients are tiny and are multiplied by large
#' climate values: `h11 = 0.0001` times `dd0 = 2000` adds 0.2 to `ln(H)`,
#' but the true `h11` could be anywhere from 0.00005 to 0.00015. When every
#' coefficient is moved at random within its rounding interval, predicted
#' volume at age 80 and each species' average climate varies by about 9 %
#' (standard deviation) for Nat1, from 3 % to 16 % depending on the species
#' (tamarack is the worst), and by about 4 % for Nat2 (at most 9 %). This is
#' in addition to every other source of uncertainty. [ung_uncertainty()]
#' includes it by default (`rounding = TRUE`).
#'
#' @section Age 0:
#' Age 0 is allowed and gives 0 for height, basal area and volume, which is
#' what the Carbon Budget Model expects at the start of a curve. The equations
#' themselves divide by age, so they cannot be evaluated at exactly 0; for
#' normal climates they approach 0 as age approaches 0.
#'
#' @section Intended use and time horizon:
#' The authors state (Ung et al. 2009, Discussion): "the models developed here
#' were designed for increment predictions over very short (< 10 years)
#' intervals, as requested within the context of the CNFI. The absence of
#' safeguards, such as an empirical adjustment to the number of merchantable
#' stems per hectare, means that the user who may want to use these models for
#' longer-term projections should use caution." (CNFI is the Canadian National
#' Forest Inventory.) A yield curve over many decades is a longer-term
#' projection in this sense.
#'
#' @section Warnings and checks:
#' With `warn = TRUE`, `ung_volume()` gives at most **one** warning per call,
#' in plain English, and only for problems you can do something about:
#' * `age`, `dd0` or `map` is missing (the prediction is `NA`);
#' * the stand is older than any stand used to fit the species' model;
#' * `dd0` or `map` is outside the climate of the plots used to fit the
#'   species' model (often a sign that the wrong degree-day variable was used);
#' * predicted volume or basal area is larger than in any fitting plot.
#'
#' The warning has class `ung2009_warning`. Other checks apply to almost every
#' yield curve (young ages, the 10-year design horizon, sensitivity to climate,
#' and disagreement between Nat1 and Nat2), so they are not raised as
#' warnings. Run [ung_check()] on the result to see all of them.
#'
#' @section Other limitations stated by the authors:
#' * The models were fitted to plots measured once, in which one species made
#'   up at least 75 % of basal area. For mixed stands the authors suggest
#'   applying the model to each species separately.
#' * The climate terms describe how volume varies from place to place; they do
#'   not predict the effect of climate change. Do not use future climate
#'   projections as inputs.
#' * The ability to predict growth over short periods was rated moderate to
#'   poor, comparable with provincial models.
#'
#' @param species Character vector. Species code, scientific name or common name
#'   (any capitalisation); see [ung_species()].
#' @param age Numeric vector. Stand age in years (0 or more).
#' @param dd0 Numeric vector. Degree-days above 0 degrees C in a year (see
#'   *Climate inputs*). If `NULL` (default), the average `dd0` of the plots used
#'   to fit that species' model is used (column `dd0_mean` of [ung_envelope]);
#'   see *Climate used when `dd0` and `map` are omitted*.
#' @param map Numeric vector. Mean annual precipitation in mm. If `NULL`
#'   (default), the average `map` of the plots used to fit that species' model
#'   is used (column `map_mean` of [ung_envelope]).
#' @param model One of `"both"` (default), `"Nat1"` or `"Nat2"`.
#' @param nat1_bias_correction Logical. `TRUE` multiplies Nat1 volume by the
#'   approximate correction described in *Nat1 volume is biased low*. Default
#'   `FALSE` (the published model).
#' @param warn Logical. Set to `FALSE` to skip the warning and the message about
#'   default climate.
#'
#' @details Arguments are matched **row by row** and recycled: each must have
#'   length 1 or the same length as the longest. Species 1 is paired with age
#'   1, species 2 with age 2, and so on. To predict several species over a range
#'   of ages, use [ung_curve()] or [ung_yield_table()], which combine every
#'   species with every age.
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
#' 965 mm, and Douglas-fir uses 2352 degree-days and 727 mm.
#'
#' The result is a prediction for a **typical stand of each species**, not for
#' any particular site. It is useful for comparing species or sketching a
#' curve. For a real stand, supply the climate of its location (see
#' [ung_climate()]), and use [ung_uncertainty()] to see how uncertain the
#' prediction is.
#'
#' @return A data.frame of class `ung_volume` with one row per input row:
#'   `species` (code), `age`, `dd0`, `map` and, depending on `model`,
#'   `H_Nat1` (dominant height, m), `G_Nat1` (basal area, m2/ha), `V_Nat1`
#'   (volume, m3/ha) and `V_Nat2` (volume, m3/ha).
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
#' @seealso [ung_yield_table()], [ung_uncertainty()], [ung_check()],
#'   [ung_climate()], [ung_species()]
#' @export
#' @examples
#' # A typical stand of each species at age 80. `dd0` and `map` are omitted, so
#' # each species uses the average climate of the plots used to fit its model
#' # (shown in the dd0 and map columns of the result)
#' ung_volume(c("black spruce", "Douglas-fir"), age = 80)
#'
#' # Trembling aspen at a boreal site, from age 0
#' aspen <- ung_volume("trembling aspen", age = seq(0, 150, by = 10),
#'                     dd0 = 2200, map = 750)
#' head(aspen)
#' ung_check(aspen)
#'
#' # Nat1 with the optional bias correction
#' ung_volume("black spruce", age = 80, dd0 = 2079, map = 965,
#'            nat1_bias_correction = TRUE)
#'
#' # Several stands at once
#' stands <- data.frame(species = c("PICE.MAR", "PINU.BAN"),
#'                      age = c(80, 60), dd0 = c(2000, 2300), map = c(900, 700))
#' ung_volume(stands$species, stands$age, stands$dd0, stands$map, model = "Nat2")
ung_volume <- function(species, age, dd0 = NULL, map = NULL,
                       model = c("both", "Nat1", "Nat2"),
                       nat1_bias_correction = FALSE, warn = TRUE) {
  model <- match.arg(model)
  .check_logical(nat1_bias_correction, "nat1_bias_correction")

  # Validate and recycle inputs, then predict
  x <- .prepare_inputs(species, age, dd0, map)
  if (isTRUE(warn)) .note_defaults(x)
  out <- cbind(x, .predict(x, model, nat1_bias_correction = nat1_bias_correction))
  attr(out, "defaulted") <- NULL
  attr(out, "nat1_bias_correction") <- nat1_bias_correction
  class(out) <- c("ung_volume", "data.frame")

  # One plain-English warning for problems the user can act on
  if (isTRUE(warn)) .warn_summary(out)
  out
}

# Stop unless `x` is a single TRUE or FALSE.
.check_logical <- function(x, name) {
  if (!isTRUE(x) && !isFALSE(x)) {
    stop("`", name, "` must be TRUE or FALSE.", call. = FALSE)
  }
  invisible(x)
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
         "range of ages, use `ung_curve()` or `ung_yield_table()`.",
         call. = FALSE)
  }

  if (any(age < 0, na.rm = TRUE)) stop("`age` cannot be negative.", call. = FALSE)
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

# Core equations, vectorised over the rows of `x`. `p` holds one parameter row
# per row of `x`; by default it is looked up from `ung_parameters` (ung_uncertainty()
# passes perturbed copies). Rows with age 0 return 0.
.predict <- function(x, model, p = NULL, nat1_bias_correction = FALSE) {
  if (is.null(p)) {
    p <- NationalModelUng2009::ung_parameters
    p <- p[match(x$species, p$species), , drop = FALSE]
  }
  age0 <- !is.na(x$age) & x$age == 0
  zero_at_age0 <- function(v) ifelse(age0, 0, v)
  out <- list()

  if (model %in% c("Nat1", "both")) {
    # Height and basal area: parameters are linear in climate, rate term is / age
    ln_h <- (p$h10 + p$h11 * x$dd0 + p$h12 * x$map) +
      (p$h20 + p$h21 * x$dd0 + p$h22 * x$map) / x$age
    ln_g <- (p$g10 + p$g11 * x$dd0 + p$g12 * x$map) +
      (p$g20 + p$g21 * x$dd0 + p$g22 * x$map) / x$age

    # Volume uses the predicted ln(H) and ln(G) *before* their Duan factors;
    # the Duan factors apply to each output only (authors' "system equations.xls":
    # ln(V) = v30 + v31*ln(H) + v32*ln(G))
    ln_v <- p$v30 + p$v31 * ln_h + p$v32 * ln_g
    v1 <- exp(ln_v) * p$CDv

    # Optional second-order Taylor correction for the H and G errors carried
    # into ln(V): each variance estimated as 2 * ln(Duan factor), errors uncorrelated
    if (isTRUE(nat1_bias_correction)) {
      s2 <- p$v31^2 * 2 * log(p$CDh) + p$v32^2 * 2 * log(p$CDg)
      v1 <- v1 * (1 + s2 / 2)
    }

    out$H_Nat1 <- zero_at_age0(exp(ln_h) * p$CDh)
    out$G_Nat1 <- zero_at_age0(exp(ln_g) * p$CDg)
    out$V_Nat1 <- zero_at_age0(v1)
  }

  if (model %in% c("Nat2", "both")) {
    ln_v2 <- (p$v10 + p$v11 * x$dd0 + p$v12 * x$map) +
      (p$v20 + p$v21 * x$dd0 + p$v22 * x$map) / x$age
    out$V_Nat2 <- zero_at_age0(exp(ln_v2) * p$CDv2)
  }

  as.data.frame(out)
}
