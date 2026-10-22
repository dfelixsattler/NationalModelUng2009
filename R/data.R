#' Parameters of the Ung et al. (2009) national models
#'
#' One row per species. Nat1 parameters were transcribed from the CTAE-derived R
#' implementation of Ung et al. (2009) and verified cell by cell against four
#' files from the model developers (`Parms.csv`, `Ung2009_NatOneWide.csv`,
#' `NatOneWide.csv`, `Fit.csv`). Nat2 parameters were verified against sheet `V`
#' of the developers' spreadsheet (all 25 species identical). The height and
#' basal-area sheets of that spreadsheet hold slightly different, unpublished
#' individual-equation estimates; they are **not** used here.
#'
#' @format A data.frame with 25 rows and 26 columns:
#' \describe{
#'   \item{species}{Species code, see [ung_species()].}
#'   \item{h10-h22}{Nat1 height parameters: `h1 = h10 + h11 * dd0 + h12 * map`,
#'     `h2 = h20 + h21 * dd0 + h22 * map`.}
#'   \item{g10-g22}{Nat1 basal-area parameters, same structure as `h`.}
#'   \item{v30, v31, v32}{Nat1 volume parameters: intercept, ln(H) and ln(BA)
#'     coefficients.}
#'   \item{CDh, CDg, CDv}{Nat1 Duan correction factors.}
#'   \item{v10-v22}{Nat2 volume parameters, same structure as `h`.}
#'   \item{CDv2}{Nat2 Duan correction factor.}
#' }
#' @source Ung, C.-H., Bernier, P.Y., Guo, X.J. and Lambert, M.-C. 2009.
#'   The Forestry Chronicle 85(1): 57-64. \doi{10.5558/tfc85057-1}
"ung_parameters"

#' Fitting-data summary of the Ung et al. (2009) national models
#'
#' Per-species mean, standard deviation, minimum and maximum of the plot
#' variables the models were fitted to. [ung_volume()] uses the minima and
#' maxima to warn when age, climate or predicted basal area or volume fall
#' outside the data (extrapolation). The paper publishes these only for black
#' spruce, jack pine and trembling aspen (its Table 2); the other 22 species come
#' from the `DATASUMMARY` sheet of the developers' spreadsheet.
#'
#' The `dd0_*` and `map_*` columns describe the climate of the fitting plots,
#' that is, the field plots used to fit each species' model (spatial variation
#' among plots, not inter-annual variation). `dd0_mean` and `map_mean` are the
#' averages that [ung_volume()] uses when `dd0` and `map` are omitted.
#'
#' @format A data.frame with 25 rows: `species` (code, see [ung_species()]),
#'   `n` (number of plots), and for each of `h` (dominant height, m), `ba` (basal
#'   area, m2/ha), `v` (volume, m3/ha), `age` (years), `dd0` (degree-days above
#'   0 degrees C) and `map` (mm): `<var>_mean`, `<var>_sd`, `<var>_min` and
#'   `<var>_max`.
#' @source Table 2 of Ung et al. (2009) and the developers' spreadsheet
#'   (`DATASUMMARY` sheet); built by `data-raw/build_envelope.R`.
"ung_envelope"
