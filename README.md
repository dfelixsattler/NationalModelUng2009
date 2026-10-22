# NationalModelUng2009

R implementation of the two national stand-volume models of

> Ung, C.-H., Bernier, P.Y., Guo, X.J. and Lambert, M.-C. 2009. A simple growth
> and yield model for assessing changes in standing volume across Canada's
> forests. *The Forestry Chronicle* 85(1): 57-64. <https://doi.org/10.5558/tfc85057-1>

Given stand **age**, annual **degree-days above 0 °C** (`dd0`) and **mean annual
precipitation** (`map`, mm), the package predicts gross merchantable volume
(m³/ha) for 25 Canadian tree species:

* **Nat1** predicts dominant height, basal area, then volume from the two.
* **Nat2** predicts volume directly.

## Install

```r
# install.packages("remotes")
remotes::install_github("dfelixsattler/NationalModelUng2009")
# Optional, to look up climate for coordinates:
remotes::install_github("bcgov/climr")
```

## Use

A step-by-step worked example (location, model choice, climate values,
prediction, warnings, sensitivity and uncertainty checks) is in the vignette:
`vignette("ung-workflow", package = "NationalModelUng2009")`.

```r
library(NationalModelUng2009)

# A yield curve (species by code, scientific name or common name)
curve <- ung_volume("trembling aspen", age = 10:150, dd0 = 2200, map = 750)
plot(curve)

# Climate for a location from climr (1981-2010 normals), then volume
clim <- ung_climate(lon = -105.5, lat = 54.1, elev = 500)
ung_volume("black spruce", age = 80, dd0 = clim$dd0, map = clim$map)

# Yield curves for several species (every species at every age)
plot(ung_curve(c("black spruce", "Douglas-fir"), age = 10:150))

# How fragile is the answer? If dd0 is off by 100 degree-days, or map by 100 mm,
# by how many percent does the predicted volume change?
ung_sensitivity("jack pine", age = 80, dd0 = 2200, map = 800)

# A typical stand of each species at age 80: omit dd0/map to use each species'
# mean fitting-plot climate (shown in the dd0 and map columns of the result)
ung_volume(c("black spruce", "Douglas-fir"), age = 80)

# Climate-uncertainty fan (Monte Carlo over dd0 and map)
fan <- ung_uncertainty("white spruce", age = seq(20, 200, by = 20),
                       dd0 = 1800, map = 700, seed = 1)
plot(fan)

ung_species()   # the 25 supported species
```

Many stands at once: pass vectors (or data frame columns) for `species`, `age`,
`dd0` and `map`; results come back as one row per stand. The values are matched
row by row (species 1 with age 1, and so on). To combine every species with
every age, use `ung_curve()`.

## Climate inputs: read this first

* `dd0` is **annual degree-days above 0 °C** (the paper's `D0`). It is **not**
  growing degree-days above 5 °C (`DD5`), and **not** ClimateNA/ClimateBC/climr
  `DD_0`, which is degree-days *below* 0 °C. Mixing them up gives wrong answers.
* `map` is annual precipitation in **mm**.
* Give **one value of each per stand**, constant over stand age: the paper
  attached a single plot-level `D0` and `P` to each plot (and reused them at both
  measurement dates for increments). They are per-year quantities, not a time
  series. They derive from interpolated climate normals "to which inter-annual
  variability has been restored"; the averaging period is not stated, so use
  values representative of the location over several decades (e.g. 1981-2010)
  and report which you used.
* Neither climr nor ClimateNA provides degree-days above 0 °C. `ung_climate()`
  derives `dd0` from variables climr does provide
  (`DD18 - DDsub18 + 365 * 18 + DDsub0`); this is an approximation, not yet
  validated against the paper's climate. With a local ClimateNA or ClimateBC
  run (annual normals containing `MAP`, `DD18`, `DD_18`, `DD_0`), use
  `ung_climate_from_climatena()`; do not pass `DD_0` as `dd0`.

## Species-mean climate and the uncertainty fan

* Leave `dd0`/`map` out of `ung_volume()` (or `ung_sensitivity()`,
  `ung_uncertainty()`) and the species mean of the fitting plots
  (`ung_envelope$dd0_mean`, `$map_mean`) is used, with a message. This gives a
  *typical stand* of each species for comparing species; it is **not** a site
  prediction.
* `ung_uncertainty()` draws `n` (`dd0`, `map`) pairs from an untruncated bivariate
  normal (bounded at 0) around your climate and reports the median and a central
  interval of volume. By default the SDs are the species' among-plot SDs in the
  fitting data (spatial, **not** inter-annual and not the error of your climate
  product); pass `sd_dd0`/`sd_map` if you know your own uncertainty, and `cor` if
  you want correlated draws. Only climate uncertainty is propagated (no
  parameter or residual error), so it is not a prediction interval. The
  `prop_outside` column gives the share of draws outside the species' fitting
  range.

## Warnings

`ung_volume()` warns (and tells you how many rows are affected) when:

| Class | Trigger |
| --- | --- |
| `ung2009_warning_age` | age < 10 years, or outside the fitting-data age range |
| `ung2009_warning_horizon` | ages for the same species and climate span more than 10 years (a yield curve or long-term projection) |
| `ung2009_warning_climate` | `dd0` or `map` outside the fitting-data range |
| `ung2009_warning_sensitivity` | ±100 degree-days or ±100 mm changes volume by > 15 % |
| `ung2009_warning_models` | Nat1 and Nat2 volumes differ by > 30 % |
| `ung2009_warning_output` | volume or basal area exceeds the largest fitting-data value |
| `ung2009_warning_na` | missing inputs |

Silence one class with `withCallingHandlers()`, or everything with `warn = FALSE`.
Ranges are per species (`ung_envelope`).

## Limitations (from the paper)

* The authors state: "the models developed here were designed for increment
  predictions over very short (< 10 years) intervals, as requested within the
  context of the CNFI. The absence of safeguards, such as an empirical
  adjustment to the number of merchantable stems per hectare, means that the
  user who may want to use these models for longer-term projections should use
  caution." (CNFI = Canadian National Forest Inventory.) A yield curve over
  many decades is a longer-term projection in this sense;
  `ung_volume()` warns (`ung2009_warning_horizon`) when one call spans more
  than 10 years of age for the same species and climate.
* Fitted to single-measurement plots dominated (≥ 75 % basal area) by one
  species; for mixed stands apply the model per species.
* Climate terms are **descriptive, not predictive**: do not use future climate
  projections to estimate climate-change impacts.
* Predictive ability for increments is moderate to poor, similar to provincial
  models.

## Provenance of parameters

Parameters were taken from the CTAE-derived implementation and are stored in
`data-raw/ung_parameters.csv` (built by `data-raw/build_parameters.R`).

* **Nat1** (h, g, v coefficients and the three Duan factors): checked cell by
  cell against `Parms.csv` (the table with standard errors),
  `Ung2009_NatOneWide.csv`, `UngNatGY/NatOneWide.csv` and `Fit.csv` (in the
  local, untracked `myfiles/` folder). All 25 species match exactly.
* **Nat2** (`v10`-`v22`, `CDv2`): checked against sheet `V` of the developers'
  spreadsheet (`Ung et al G&Y V, H and G models with DegreeDays.xls`). All 25
  species match exactly. The `H` and `G` sheets of that file are slightly
  different, unpublished individual models and are not used.
* **Fitting-data ranges** (`ung_envelope`): per-species min/max/mean/SD from the
  spreadsheet's `DATASUMMARY` sheet (`data-raw/build_envelope.R`).

## Licence

MIT, Copyright His Majesty the King in Right of Canada, as represented by the
Minister of Natural Resources.
