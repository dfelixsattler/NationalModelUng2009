# NationalModelUng2009

R implementation of the two national stand-volume models of

> Ung, C.-H., Bernier, P.Y., Guo, X.J. and Lambert, M.-C. 2009. A simple growth
> and yield model for assessing changes in standing volume across Canada's
> forests. *The Forestry Chronicle* 85(1): 57-64. <https://doi.org/10.5558/tfc85057-1>

Given a stand's **age**, the yearly **degree-days above 0 °C** (`dd0`) and the
**mean annual precipitation** (`map`, mm) at its location, the package predicts
gross merchantable volume (m³/ha) for 25 Canadian tree species. In the paper,
this is the gross total volume of the live merchantable trees in the stand,
where a merchantable tree is one with a diameter at breast height greater than
9 cm. It is meant for
people who need a volume-by-age curve, for example as input to the Carbon
Budget Model (CBM), or for research on an area of Canada.

The paper has two models:

* **Nat1** first predicts dominant height (H, m) and basal area (G, m²/ha), and
  then predicts volume from H and G.
* **Nat2** predicts volume (V, m³/ha) directly from age and climate.

## Install

```r
# install.packages("remotes")
remotes::install_github("dfelixsattler/NationalModelUng2009")
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

# The same, with an uncertainty interval (lower and upper columns)
tab <- ung_yield_table("black spruce", age = seq(0, 200, by = 10),
                       dd0 = 2079, map = 965, uncertainty = TRUE, seed = 1)

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
| `ung_yield_table()` | Simple table of volume by age, one model (Nat2 by default), long or wide layout, optional uncertainty interval. Start here. |
| `ung_uncertainty()` | Volume with an uncertainty interval from climate uncertainty and the rounding of the parameters. Has a `plot()` method. |
| `ung_check()` | Lists every caution that applies to a set of predictions, with the number of rows affected. |
| `ung_volume()` | Predicts H, G and V for individual stands, matched row by row (stand 1 with age 1, and so on). |
| `ung_curve()` | Every species at every age, with both models. Has a `plot()` method. |
| `ung_sensitivity()` | By how many percent volume changes if `dd0` is off by 100 degree-days or `map` by 100 mm. |
| `ung_climate()`, `ung_climate_from_climatena()` | Get `dd0` and `map` for a location from climr, or from your own ClimateNA/ClimateBC output. |
| `ung_species()` | The 25 species, with codes, scientific and common names. |

## Which model to use

**Use Nat2** (the default of `ung_yield_table()`). It predicts average volume
directly.

Nat1 predicts H and G first and then puts these predictions into its volume
equation. That equation was fitted with *measured* H and G, so its small
correction factor does not allow for the much larger error in *predicted* H and
G. As a result, Nat1 volume as published is **biased low**: across the 25
species, at age 80 and each species' average climate, Nat2 is a median of
about **20 % higher** than Nat1.

`nat1_bias_correction = TRUE` multiplies Nat1 volume by a second-order Taylor
series correction (between 1.05 and 1.46 depending on the species). It assumes
the errors in H and G are uncorrelated, because the authors did not publish
their correlation. With the correction, the median gap between Nat2 and Nat1
falls to under 1 %. This correction was added by this package; it is not part of
the published model, so it is off by default.

### How Nat1 links height and basal area to volume

The Nat1 volume equation is
`ln(V) = v30 + v31 * ln(H) + v32 * ln(G)`. The `ln(H)` and `ln(G)` it uses are
the values straight from the height and basal-area equations, **before** the
Duan correction factors (explained below) are applied to H and G. The H and G
columns in the output *are* corrected. This is how the authors fitted and wrote
the model, and how earlier R scripts calculated it. It matters: putting the
corrected H and G into the volume equation instead would raise Nat1 volume by
about a third for black spruce.

## Parameters are rounded: read this

The paper and every file supplied by the authors give the model parameters to
only **4 decimal places** (a few large values to 4 significant digits). The
unrounded values are not available and will not become available, so the
package uses the rounded ones.

This rounding is not harmless. Some parameters are tiny and are multiplied by
large climate values: for example, a parameter of 0.0001 multiplied by 2000
degree-days adds 0.2 to the logarithm of height, but the true parameter could be
anywhere between 0.00005 and 0.00015. Moving every parameter at random within
its rounding interval changes predicted volume (at age 80 and each species'
average climate) by about:

* **9 %** for Nat1 (standard deviation; from 3 % to 16 % depending on the species);
* **4 %** for Nat2 (at most 9 %).

This uncertainty comes on top of all others. `ung_uncertainty()` and
`ung_yield_table(uncertainty = TRUE)` include it by default.

## Uncertainty

Uncertainty is part of the main workflow. `ung_uncertainty()` (and
`ung_yield_table(uncertainty = TRUE)`) repeats the prediction many times
(Monte Carlo simulation), each time with:

* slightly different climate: `dd0` and `map` are drawn from a normal
  distribution around your values. By default the spread is the variation of
  `dd0` and `map` among the plots used to fit that species' model. This is
  variation between places, not between years, and not the error of a climate
  dataset. If you know the uncertainty of your own climate values, give it with
  `sd_dd0` and `sd_map`;
* slightly different parameters, within their rounding interval (see above).
  Use `rounding = FALSE` to leave this out.

The result is the median and a central interval (90 % by default) of the
predictions. It does **not** include the statistical uncertainty of the fitted
parameters (standard errors exist for Nat1 only, without the correlations needed
to combine them) or the plot-to-plot variation around the model. Real stands of
the same age and climate will vary more than the interval shows.

## Climate inputs

* `dd0` is the yearly sum of **degree-days above 0 °C** (the paper's `D0`): for
  each day, the mean temperature if it is above 0 °C, otherwise 0, added up over
  the year.
* Be careful with names in climate software. `DD5` (degree-days above 5 °C) is
  **not** `dd0`. In ClimateNA, `DD_0`, and in climr, `DDsub0`, are degree-days
  **below** 0 °C, which measure how cold the winter is: the opposite quantity.
  Passing any of these as `dd0` gives wrong answers.
* No climate package provides `dd0` directly. `ung_climate()` (climr) and
  `ung_climate_from_climatena()` calculate it from three variables they do
  provide: degree-days above 18 °C, below 18 °C and below 0 °C. This is an
  approximation and has not yet been checked against the climate the authors
  used.
* `map` is the yearly precipitation in **mm**.
* Give **one value of each per stand**, the same at every age. The models were
  fitted with one `dd0` and one `map` per plot, describing the long-term climate
  of the location, not the weather of a particular year.
* The authors used interpolated climate normals "to which inter-annual
  variability has been restored" (McKenney et al. 2001), and do not explain
  this further. Our reading is that they started from maps of long-term average
  climate (built from weather-station records) and then added back the
  year-to-year ups and downs that averaging removes. The averaging period is not
  stated. Use values that describe the location over several decades (for
  example the 1981-2010 normals) and report which you used.
* If you leave out `dd0` and/or `map`, the package uses, **for each species, the
  average climate of the plots used to fit its model** (for example 2079
  degree-days and 965 mm for black spruce) and says so in a message. The result
  is then a typical stand of that species, not a prediction for a particular
  site.
* Climate in these models is **descriptive, not predictive**: do not use future
  climate scenarios to estimate the effects of climate change.

## Duan correction factor, in plain words

The models predict the *logarithm* of height, basal area and volume. Turning a
logarithm back into a value with `exp()` gives roughly the middle (median)
stand, which is lower than the average stand. Multiplying by a small factor,
called the Duan correction factor after the statistician who proposed it,
brings the result back up to the average. The factors are published with the
parameters (for black spruce: 1.02 for H, 1.32 for G, 1.001 for Nat1 volume and
1.15 for Nat2 volume) and are always applied by the package.

## Warnings and checks

`ung_volume()` (and the functions built on it) gives **at most one warning per
call**, written in plain English, and only for problems you can do something
about:

* an input is missing;
* the stand is older than any stand used to fit the model;
* the climate is outside the range of the fitting plots;
* predicted volume or basal area is larger than in any fitting plot.

Other cautions apply to almost every yield curve (young ages, curves longer
than the 10-year span the models were designed for, strong sensitivity to
climate, Nat1 and Nat2 disagreeing). Warning about them every time would teach
users to ignore warnings, so they are listed only when you ask, with
`ung_check()`. All warnings have the class `ung2009_warning`; `warn = FALSE`
turns them off.

## Age 0

Age 0 is allowed and gives 0 for H, G and V, which is how yield tables such as
those used by the CBM start. Below about 10 years, and below the youngest fitted
stand, predictions are close to 0 and are not reliable (see `ung_check()`).

## Limitations (from the paper)

* The authors state: "the models developed here were designed for increment
  predictions over very short (< 10 years) intervals, as requested within the
  context of the CNFI. The absence of safeguards, such as an empirical
  adjustment to the number of merchantable stems per hectare, means that the
  user who may want to use these models for longer-term projections should use
  caution." (CNFI = Canadian National Forest Inventory.) A yield curve over many
  decades is a longer-term projection in this sense.
* The models were fitted to plots measured once and dominated by one species
  (at least 75 % of basal area). For mixed stands, apply the model to each
  species.
* Their ability to predict growth over time was moderate to poor, similar to
  provincial models.

## Where the parameters come from

The parameters are stored in `data-raw/ung_parameters.csv` and built by
`data-raw/build_parameters.R` from an R implementation supplied with the
authors' files.

* **Nat1** (H, G and V parameters and their three Duan factors): checked value by
  value against four files from the authors (`Parms.csv`,
  `Ung2009_NatOneWide.csv`, `NatOneWide.csv`, `Fit.csv`) and against Tables 4
  and 5 of the paper for black spruce, jack pine and trembling aspen.
* **Nat2**: checked against sheet `V` of the authors' spreadsheet
  (`Ung et al G&Y V, H and G models with DegreeDays.xls`). The `H` and `G`
  sheets of that file hold slightly different, unpublished estimates and are not
  used.
* **Fitting-data ranges** (`ung_envelope`): mean, standard deviation, minimum
  and maximum per species, from the spreadsheet's `DATASUMMARY` sheet
  (`data-raw/build_envelope.R`).

The authors' files are kept outside the git repository.

## Licence

MIT, Copyright His Majesty the King in Right of Canada, as represented by the
Minister of Natural Resources.