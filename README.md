# NationalModelUng2009

<!-- badges: start -->
[![R-CMD-check](https://github.com/dfelixsattler/NationalModelUng2009/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dfelixsattler/NationalModelUng2009/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dfelixsattler/NationalModelUng2009/blob/main/LICENSE.md)
[![Paper DOI](https://img.shields.io/badge/DOI-10.5558%2Ftfc85057--1-blue.svg)](https://doi.org/10.5558/tfc85057-1)
<!-- badges: end -->

R implementation of the two national stand-volume models of

> Ung, C.-H., Bernier, P.Y., Guo, X.J. and Lambert, M.-C. 2009. A simple growth
> and yield model for assessing changes in standing volume across Canada's
> forests. *The Forestry Chronicle* 85(1): 57-64. <https://doi.org/10.5558/tfc85057-1>

Given a stand's **age**, the yearly **degree-days above 0 °C** (`dd0`) and the
**mean annual precipitation** (`map`, mm) at its location, the package predicts
gross merchantable volume (m³/ha) for 25 Canadian tree species. In the paper,
this is the gross total volume of the live merchantable trees in the stand,
where a merchantable tree is one with a diameter at breast height greater than
9 cm. Users should be aware of the limitations of the models (e.g., original authors' intended projection period; biases in the Nat1 equation, etc.). These are documented in the text below and in the associated functions.

The paper has two models:

* **Nat1** first predicts dominant height (H, m) and basal area (G, m²/ha), and
  then predicts volume from H and G. Specifically:
  * ln(H) = (h10 + h11·dd0 + h12·map) + (h20 + h21·dd0 + h22·map) / age
  * ln(G) = (g10 + g11·dd0 + g12·map) + (g20 + g21·dd0 + g22·map) / age
  * ln(V) = v1 + v2·ln(H) + v3·ln(G)
* **Nat2** predicts volume (V, m³/ha) directly from age and climate. Specifically, ln(V) = (b0 + b1·dd0 + b2·map) + (b3 + b4·dd0 + b5·map) / age

## Install

```r
# install.packages("remotes")
remotes::install_github("dfelixsattler/NationalModelUng2009", build_vignettes = TRUE)
# Optional, to look up climate for coordinates:
remotes::install_github("bcgov/climr")
```

## Quick start: a yield table

```r
library(NationalModelUng2009)

# Volume of black spruce every 10 years from age 0 to 200, at a site with
# 2079 degree-days above 0 °C and 965 mm of precipitation per year.
# Nat2 is used by default. Volume is 0 at age 0.
tab <- ung_yield_table("black spruce", age = seq(0, 200, by = 10),
                       dd0 = 2079, map = 965)

# The same, with an uncertainty interval (lower and upper columns).
# The SDs here are illustration values only; see Uncertainty below.
tab <- ung_yield_table("black spruce", age = seq(0, 200, by = 10),
                       dd0 = 2079, map = 965, uncertainty = TRUE,
                       sd_dd0 = 100, sd_map = 50, seed = 1)

# One row per curve and one column per age (vol_0, vol_10, ...)
ung_yield_table(c("black spruce", "jack pine"), age = seq(0, 200, by = 10),
                dd0 = 2079, map = 965, format = "wide")

# List the cautions that apply to these predictions
ung_check(tab)
```

A step-by-step worked example is in the vignette:
`vignette("ung-workflow", package = "NationalModelUng2009")`.

## Main functions

| Function | What it does |
| --- | --- |
| `ung_yield_table()` | Simple table of volume by age (0 to 150 by default), one model (Nat2 by default), long or wide layout, optional uncertainty interval, optional Nat1 height and basal area (`include_hg = TRUE`). Has a `plot()` method. Start here. |
| `ung_check()` | Lists every caution that applies to a set of predictions, with the number of rows affected. |
| `ung_climate()`, `ung_climate_from_climatena()` | Get `dd0` and `map` (1981–2010 averages by default) for a location from [climr](https://github.com/bcgov/climr) or a local copy of ClimateNA (Windows), or from your own ClimateNA/ClimateBC output. |
| `ung_species()` | The 25 species, with codes, scientific and common names. |
| `?ung_models` | Help page on the models: equations, climate inputs, which model to use, the Nat1 correction and limitations. |

## Which model to use

**User discretion required**: Nat2 is the default of `ung_yield_table()` as it predicts average volume
directly.

Nat1 predicts H and G first and then puts these predictions into its volume
equation. The current package uses the published equations and parameters. As such, Nat1 volume is **biased low**: across the 25 species,
at age 80 and each species' average climate, Nat2 is a median of about
**20 % higher** than Nat1 (see next section). For this reason, **Nat1 has been made available with an optional 
bias correction.**

### Why Nat1 volume includes a correction option

1. The models predict the *logarithm* of volume. Taking `exp()` of a predicted
   log gives the middle (median) stand, not the average stand (assuming the
   errors on the log scale are roughly symmetric, as in a normal distribution).
2. A Duan factor (as used by the original authors and always applied within this package) is applied to move the median up to
   the average. Its size should reflect *all* the scatter of ln(V) at a given
   age and climate.
3. In Nat1 that scatter has three sources: (i) the scatter of the volume equation
   itself, (ii) the error in predicted ln(H) (times `v2`) and (iii) the error in
   predicted ln(G) (times `v3`).
4. Nat1's volume Duan factor (`CDv`, about 1.001) was estimated with *measured* H and
   G, where volume is almost exactly determined. It covers only the first
   source (i.e., the scatter of the volume equation itself). The errors carried over from predicted H and G, mostly from G, are
   not accounted for. This is why uncorrected Nat1 volume is biased low.
5. Nat2 has a single equation from age and climate straight to volume. Its
   residual already contains all the scatter, so its Duan factor (`CDv2`, 1.15 for
   black spruce) accounts for everything and needs no correction.
6. For Nat1, the missing scatter can be estimated (given some assumptions). Each Duan factor gives the
   variance of its log errors, about `2 * ln(CD)`. The extra variance that H
   and G add to ln(V) is
   `s2 = v2^2 * 2 * ln(CDh) + v3^2 * 2 * ln(CDg)`, and a second-order Taylor
   series expansion gives the missing factor, about `1 + s2 / 2`.
   `nat1_bias_correction = TRUE` multiplies Nat1 volume by this factor, in
   addition to `CDv`.

The correction assumes that the errors in H and G are **uncorrelated** (the
authors did not publish their correlation), that the log-scale errors are
roughly normal, and that they are independent of the volume equation's own
scatter. It ranges from 1.05 to 1.46 depending on the species (1.29 for black
spruce). With the correction applied, the median gap between Nat2 and Nat1 falls from about 20 % to
under 1 %.

Why does this matter? Normally, a chosen yield curve is used to represent every hectare of a particular stand type (i.e., a stratum), and one multiplies the yields by total area to get total volume for that particular stand type. That calculation needs the average volume per hectare, not the volume per hectare of the median stand. The correction for Nat1 was added as an option (off by default) in this package; it was not part of the published model.


## A note on parameters

The paper and the files that were supplied to create this package give the model parameters to
only **4 decimal places** (a few large values to 4 significant digits).

This rounding is not harmless. Some parameters are tiny and are multiplied by
large climate values: for example, a parameter of 0.0001 multiplied by 2000
degree-days adds 0.2 to the logarithm of height, but the true parameter could be
anywhere between 0.00005 and 0.00015. Moving every parameter at random within
its rounding interval changes predicted volume. As an example, at age 80 and using each species'
average climate, changes are around:

* **9 %** for Nat1 (standard deviation; from 4 % to 16 % depending on the species);
* **4 %** for Nat2 (at most 9 %).

This uncertainty comes on top of the other uncertainties (see below). Users should simply be aware of this.



## Uncertainty

`ung_yield_table(uncertainty = TRUE)` adds two columns, `lower` and `upper`.

**What you get.** The range of volume if your `dd0` and `map` were off by
about `sd_dd0` and `sd_map`. The package predicts volume 1000 times, each time
drawing `dd0` and `map` at random (normal distribution, drawn independently)
around your values. At each age, `lower` and `upper` hold the middle 90 % of
the 1000 volumes. The `volume` column is unchanged: it is the prediction at
your exact `dd0` and `map`.

**What you must supply.** `sd_dd0` (degree-days) and `sd_map` (mm): how
uncertain the stand's long-term (normal) `dd0` and `map` are. Do not use the
year-to-year standard deviation: the model uses long-term climate, so
year-to-year variation would make the interval too wide. climr and ClimateNA
(and so `ung_climate()`) give one value per location, with no standard
deviation. Other climate tools, such as BioSIM, can simulate many replicates
of the climate at a location: average each replicate over many years, then
use the standard deviation of these averages.

**What you do not get.** The interval covers climate only. It does not
include:

* error in the fitted parameters (the authors published standard errors for
  Nat1 only, without the correlations needed to combine them);
* stand-to-stand variation: real stands of the same age and climate vary more
  than the interval shows;
* rounding of the parameters (see above);
* the model limits (long projections, young ages, extrapolation; see
  `ung_check()`).

For Nat1, use `nat1_bias_correction = TRUE`; otherwise both the volume and the
interval are biased low.

## Climate inputs

* `dd0` is the yearly sum of **degree-days above 0 °C** (the paper's `D0`): for
  each day, the mean temperature if it is above 0 °C, otherwise 0, added up over
  the year.
* Be careful with names in climate software. `DD5` (degree-days above 5 °C) is
  **not** `dd0`. In ClimateNA, `DD_0`, and in climr, `DDsub0`, are degree-days
  **below** 0 °C, which measure how cold the winter is: the opposite quantity.
* Climate packages tested (ClimateNA, climr) during the creation of the current package did not provide `dd0` directly. `ung_climate()` (from climr or a local copy of ClimateNA) and
  `ung_climate_from_climatena()` (from your own ClimateNA/ClimateBC output) derive it from the variables which are
  provided: degree-days above 18 °C, below 18 °C and below 0 °C. This is an
  approximation and has not yet been checked against the climate the authors
  used.
* `map` is the yearly precipitation in **mm**.
* The models use climate, but that climate is held fixed across all ages. For the two climate variables, users supply **one value of each per stand**. Those same values are used at every age. The models were
  fitted with one `dd0` and one `map` per plot, describing the long-term climate
  of the location, not the weather of a particular year.
* The authors used interpolated climate normals "to which inter-annual
  variability has been restored" (McKenney et al. 2001). This is interpreted as meaning that the authors started from maps of long-term average
  climate (built from weather-station records) and then added back the
  year-to-year ups and downs that averaging removes. The averaging period is not
  stated. Thus, it is recommended that users apply values that describe the location over several decades (for
  example the 1981-2010 normals).
* If you leave out `dd0` and/or `map`, the package uses, **for each species, the
  average climate of the plots used to fit its model** (for example 2079
  degree-days and 965 mm for black spruce). These values were taken directly from the paper (Table 2) and the files that were supplied to create this package.
* Climate in these models is **descriptive, not predictive**: do not use future
  climate scenarios to estimate the effects of climate change.


## Age 0

Starting yield curves from age 0 is allowed and gives 0 for H, G and V. However, note that very young stands are poorly represented in the fitting data (see `ung_check()`, which flags volumes that are generated for ages younger than the youngest stands used in fitting for that species and for ages under 10 years for all species).

## Limitations (from the paper)

* The authors state: "the models developed here were designed for increment
  predictions over very short (< 10 years) intervals".
* The models were fitted to plots measured once and dominated by one species
  (at least 75 % of basal area). For mixed stands, apply the model to each
  species.
* Their ability to predict growth over time was moderate to poor (see Fig. 2 in the paper).


## Warnings and checks

`ung_yield_table()` gives **at most one warning per
call** for problems you can do something
about:

* an input (`age`, `dd0` or `map`) is `NA`, so the prediction is `NA`. (If you
  leave out `dd0` and `map` altogether, there is no warning: a message says that
  the species' average climate is used.);
* the stand is older than any stand used to fit the model;
* the climate is outside the range of the fitting plots;
* predicted volume or basal area is larger than in any fitting plot;
* Nat2 only (`curve_not_rising`): at this climate, the Nat2 curve reaches half
  its maximum volume before age 10 or does not rise with age (consider Nat1).

Warnings may also be listed on demand with
`ung_check()`. All other cautions previously discussed still apply.


## Licence

MIT, Copyright His Majesty the King in Right of Canada, as represented by the
Minister of Natural Resources.