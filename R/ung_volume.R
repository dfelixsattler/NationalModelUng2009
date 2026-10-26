#' About the Ung et al. (2009) national models
#'
#' How the package predicts gross merchantable volume (m3/ha) from stand age
#' and two climate values, using the two national growth-and-yield models of
#' Ung et al. (2009): the equations, the climate inputs, which model to use and
#' the limitations. The predictions themselves are made with
#' [ung_yield_table()].
#'
#' * **Nat1** first predicts dominant height `H` (m) and basal area `G`
#'   (m2/ha), then predicts volume from them:
#'   `ln(H) = h1 + h2 / age`, `ln(G) = g1 + g2 / age` and
#'   `ln(V) = v1 + v2 * ln(H) + v3 * ln(G)`. Each of `h1`, `h2`, `g1` and
#'   `g2` changes in a straight line with `dd0` and `map` (for example
#'   `h1 = h10 + h11 * dd0 + h12 * map`).
#' * **Nat2** predicts volume directly:
#'   `ln(V) = (b0 + b1 * dd0 + b2 * map) + (b3 + b4 * dd0 + b5 * map) / age`.
#'
#' Parameter names follow Table 4 of the paper (`b0` to `b5` are the
#' paper's beta0 to beta5); the values are in [ung_parameters].
#'
#' Volume is the gross volume of live merchantable trees, that is, trees with a
#' diameter at breast height greater than 9 cm.
#'
#' @section Which model to use:
#' The choice is left to the user. **Nat2** is the default of
#' [ung_yield_table()] because it predicts average volume directly.
#' **Nat1** also gives height and basal area (`include_hg = TRUE`), but its
#' published volume is biased low (Nat2 is a median of about 20 % higher). For this reason Nat1
#' has an optional bias correction; read *Why Nat1 volume needs a correction*.
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
#' 1981-2010 normals, which is what [ung_climate()] returns by default) and report which
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
#' 1.15 for Nat2 volume. The package applies these factors to volume only.
#'
#' @section How Nat1 calculates volume:
#' The Nat1 volume equation uses the predicted height and basal area. `H` and
#' `G` (from `include_hg = TRUE`) are reported without their Duan factors, so
#' they are the same values the volume equation uses.
#'
#' @section Why Nat1 volume needs a correction:
#' Uncorrected Nat1 volume is biased low. Step by step:
#'
#' 1. The models predict the logarithm of volume. Taking `exp()` of a predicted
#'    log gives the middle (median) stand, not the average stand (assuming the
#'    errors on the log scale are roughly symmetric, as in a normal
#'    distribution).
#' 2. A Duan factor is multiplied on to move the median up to the average. Its
#'    size should reflect *all* the scatter of `ln(V)` at a given age and
#'    climate.
#' 3. In Nat1, that scatter has three sources: the scatter of the volume
#'    equation itself, the error in predicted `ln(H)` (times `v2`) and the
#'    error in predicted `ln(G)` (times `v3`).
#' 4. Nat1's volume factor (`CDv`, about 1.001) was estimated with *measured* H
#'    and G, where volume is almost exactly determined. It covers only the
#'    first source. The errors carried over from predicted H and G, mostly from
#'    G (whose own factor `CDg` is 1.1 to 1.6), are not accounted for. This is
#'    why uncorrected Nat1 volume is biased low.
#' 5. Nat2 has a single equation from age and climate straight to volume. Its
#'    one residual already contains all the scatter, so its factor (`CDv2`,
#'    1.15 for black spruce) accounts for everything and needs no correction.
#' 6. For Nat1, the missing scatter can be estimated. Each Duan factor gives the
#'    variance of its log errors, about `2 * ln(CD)`. The extra variance that H
#'    and G add to `ln(V)` is then
#'    `s2 = v2^2 * 2 * ln(CDh) + v3^2 * 2 * ln(CDg)`, and a second-order
#'    Taylor-series expansion gives the missing factor, about `1 + s2 / 2`.
#'    `nat1_bias_correction = TRUE` multiplies Nat1 volume by this factor, in
#'    addition to `CDv`.
#'
#' The correction assumes that (a) the errors in H and G are **uncorrelated**
#' (the authors did not publish their correlation), (b) the log-scale errors
#' are roughly normal, and (c) these errors are independent of the volume
#' equation's own scatter. It ranges from about 1.05 to 1.46 among species
#' (1.29 for black spruce).
#'
#' **Evidence.** Across the 25 species, at age 80 and each species' average
#' climate, Nat2 volume is a median of about 20 % higher than uncorrected Nat1
#' volume. With the correction, the median gap shrinks to under 1 %.
#'
#' **Why it matters.** In the Carbon Budget Model and similar tools, a chosen
#' yield curve usually represents every hectare of a particular stand type
#' (stratum), and its yields are multiplied by the total area to get the total
#' volume of that stand type. That calculation needs the average volume per
#' hectare, not the volume per hectare of the median stand.
#'
#' **Why it is off by default.** The correction was added as an option in this
#' package; it is not part of the published model, and it rests on the
#' assumptions above. Nat2 does not need it. Height (`H`) and basal area
#' (`G`) are not changed by it.
#'
#' @section Age 0:
#' Age 0 is allowed and gives 0 for height, basal area and volume, which is
#' what the Carbon Budget Model expects at the start of a curve. The equations
#' themselves divide by age, so they cannot be evaluated at exactly 0; for
#' normal climates they approach 0 as age approaches 0. Very young stands are
#' poorly represented in the fitting data: [ung_check()] flags ages under 10
#' years, and ages younger than the youngest fitting plot of that species.
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
#' With `warn = TRUE`, [ung_yield_table()] gives at most **one** warning per call,
#' in plain English, and only for problems you can do something about:
#' * `age`, `dd0` or `map` is missing (the prediction is `NA`);
#' * the stand is older than any stand used to fit the species' model;
#' * `dd0` or `map` is outside the climate of the plots used to fit the
#'   species' model (often a sign that the wrong degree-day variable was used);
#' * predicted volume or basal area is larger than in any fitting plot;
#' * Nat2 only: at this climate, Nat2 volume reaches half of its maximum before
#'   age 10 or does not rise with age at all. In Nat2,
#'   `b3 + b4 * dd0 + b5 * map` (the part divided by age) can be close to
#'   zero or above it, even inside the fitting climate, mainly for
#'   Douglas-fir, white spruce, subalpine fir, red pine and eastern white pine
#'   in dry places. Nat1 usually gives a normal rising curve there.
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
#' [ung_climate()]), and use `ung_yield_table(uncertainty = TRUE)` to see how
#' much the prediction changes with climate.
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
#' @seealso [ung_yield_table()], [ung_check()],
#'   [ung_climate()], [ung_species()]
#' @name ung_models
NULL

# Predict H, G and V row by row (species 1 with age 1, and so on). Internal
# engine for ung_yield_table() and ung_check().
ung_volume <- function(species, age, dd0 = NULL, map = NULL,
                       model = "both",
                       nat1_bias_correction = FALSE, warn = TRUE) {
  model <- .check_choice(model, c("both", "Nat1", "Nat2"), "model")
  .check_logical(nat1_bias_correction, "nat1_bias_correction")

  # Validate and recycle inputs, then predict
  x <- .prepare_inputs(species, age, dd0, map)
  if (isTRUE(warn)) .note_defaults(x)
  out <- cbind(x, .predict(x, model, nat1_bias_correction = nat1_bias_correction))
  attr(out, "defaulted") <- NULL
  attr(out, "nat1_bias_correction") <- nat1_bias_correction

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

#' Check that an option is exactly one of the allowed values
#' @noRd
.check_choice <- function(x, choices, name) {
  if (!is.character(x) || length(x) != 1L || !x %in% choices) {
    stop("`", name, "` must be one of: ",
         paste0('"', choices, '"', collapse = ", "), ".", call. = FALSE)
  }
  x
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
         "range of ages, use `ung_yield_table()`.",
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
# per row of `x`; by default it is looked up from `ung_parameters`. Rows with
# age 0 return 0.
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

    # Volume uses the predicted ln(H) and ln(G) (authors' "system equations.xls"):
    # ln(V) = v1 + v2*ln(H) + v3*ln(G)
    ln_v <- p$v1 + p$v2 * ln_h + p$v3 * ln_g
    v1 <- exp(ln_v) * p$CDv

    # Optional second-order Taylor correction for the H and G errors carried
    # into ln(V): each variance estimated as 2 * ln(Duan factor), errors uncorrelated
    if (isTRUE(nat1_bias_correction)) {
      s2 <- p$v2^2 * 2 * log(p$CDh) + p$v3^2 * 2 * log(p$CDg)
      v1 <- v1 * (1 + s2 / 2)
    }

    # H and G are reported without their Duan factors (CDh, CDg)
    out$H_Nat1 <- zero_at_age0(exp(ln_h))
    out$G_Nat1 <- zero_at_age0(exp(ln_g))
    out$V_Nat1 <- zero_at_age0(v1)
  }

  if (model %in% c("Nat2", "both")) {
    ln_v2 <- (p$b0 + p$b1 * x$dd0 + p$b2 * x$map) +
      (p$b3 + p$b4 * x$dd0 + p$b5 * x$map) / x$age
    out$V_Nat2 <- zero_at_age0(exp(ln_v2) * p$CDv2)
  }

  as.data.frame(out)
}
