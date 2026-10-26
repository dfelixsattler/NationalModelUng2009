#' Parameters of the Ung et al. (2009) national models
#'
#' One row per species. The parameters were read from an R implementation of
#' Ung et al. (2009) supplied with the developers' files
#' (`Ung_stand_volume_function.R`) and checked value by value against four
#' files from the model developers (`Parms.csv`, `Ung2009_NatOneWide.csv`,
#' `NatOneWide.csv`, `Fit.csv`) and against Tables 4 and 5 of the paper for
#' black spruce, jack pine and trembling aspen. Column names follow Table 4 of
#' the paper (the developers' files use `v30`-`v32` for `v1`-`v3` and
#' `v10`-`v22` for `b0`-`b5`). Nat2 parameters were also
#' checked against sheet `V` of the developers' spreadsheet (all 25 species
#' identical). The height (H) and basal-area (G) sheets of that spreadsheet hold
#' slightly different, unpublished estimates from fitting each equation on its
#' own; they are **not** used here.
#'
#' @format A data.frame with 25 rows and 26 columns:
#' \describe{
#'   \item{species}{Species code, see [ung_species()].}
#'   \item{h10-h22}{Nat1 dominant height (H) parameters:
#'     `h1 = h10 + h11 * dd0 + h12 * map`, `h2 = h20 + h21 * dd0 + h22 * map`.}
#'   \item{g10-g22}{Nat1 basal area (G) parameters, same structure as `h`.}
#'   \item{v1, v2, v3}{Nat1 volume parameters: intercept, and the
#'     coefficients of ln(H) and ln(G).}
#'   \item{CDh, CDg, CDv}{Nat1 Duan correction factors (see *Duan correction
#'     factor* in [ung_models]).}
#'   \item{b0-b5}{Nat2 volume parameters (beta0 to beta5 in the paper):
#'     `ln(V) = (b0 + b1 * dd0 + b2 * map) + (b3 + b4 * dd0 + b5 * map) / age`.}
#'   \item{CDv2}{Nat2 Duan correction factor.}
#' }
#' @source Ung, C.-H., Bernier, P.Y., Guo, X.J. and Lambert, M.-C. 2009.
#'   The Forestry Chronicle 85(1): 57-64. \doi{10.5558/tfc85057-1}
"ung_parameters"

#' Fitting-data summary of the Ung et al. (2009) national models
#'
#' Per-species mean, standard deviation, minimum and maximum of the plot
#' variables the models were fitted to. [ung_yield_table()] and [ung_check()] use the
#' minima and maxima to flag when age, climate or predicted basal area (G) or
#' volume (V) fall outside the data (extrapolation). The paper publishes these only for black
#' spruce, jack pine and trembling aspen (its Table 2); the other 22 species come
#' from the `DATASUMMARY` sheet of the developers' spreadsheet.
#'
#' The `dd0_*` and `map_*` columns describe the climate of the fitting plots,
#' that is, the field plots used to fit each species' model (spatial variation
#' among plots, not inter-annual variation). `dd0_mean` and `map_mean` are the
#' averages that [ung_yield_table()] uses when `dd0` and `map` are omitted.
#'
#' @format A data.frame with 25 rows: `species` (code, see [ung_species()]),
#'   `n` (number of plots), and for each of `h` (dominant height H, m), `g` (basal
#'   area G, m2/ha), `v` (volume V, m3/ha), `age` (years), `dd0` (degree-days above
#'   0 degrees C) and `map` (mm): `<var>_mean`, `<var>_sd`, `<var>_min` and
#'   `<var>_max`.
#' @source Table 2 of Ung et al. (2009) and the developers' spreadsheet
#'   (`DATASUMMARY` sheet); built by `data-raw/build_envelope.R`.
"ung_envelope"

#' Example stands
#'
#' Ten made-up stands used in the vignette (`vignette("ung-workflow")`). Each
#' stand has a location and up to three species.
#'
#' @format A data.frame with 10 rows: `stand_id`, `lat` and `lon` (decimal
#'   degrees), `elev` (metres) and `sp1`, `sp2`, `sp3` (species common names
#'   accepted by the package; `NA` when the stand has fewer species).
#' @source Invented for illustration; built by
#'   `data-raw/build_example_stands.R`.
"example_stands"

#' Climate of the example stands
#'
#' Degree-days above 0 degrees C (`dd0`) and mean annual precipitation (`map`,
#' mm) for [example_stands], as returned by
#' `ung_climate(source = "climatena")` with ClimateNA v7.60 (1981-2010
#' averages), rounded to whole numbers.
#'
#' @format A data.frame with 10 rows: `id` (the `stand_id` of
#'   [example_stands]), `dd0` and `map`.
#' @source ClimateNA v7.60; built by `data-raw/build_example_stands.R`.
"example_climate"