#' Parameters of the Ung et al. (2009) national models
#'
#' One row per species. Parameters were transcribed from the CTAE-derived R
#' implementation of Ung et al. (2009) and checked only against the published
#' fitting-data means for black spruce, jack pine and trembling aspen (see the
#' package tests); the parameter tables of the paper were not available in
#' machine-readable form.
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
