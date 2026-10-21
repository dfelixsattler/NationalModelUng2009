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

```r
library(NationalModelUng2009)

# A yield curve (species by code, scientific name or common name)
curve <- ung_volume("trembling aspen", age = 10:150, dd0 = 2200, map = 750)
plot(curve)

# Climate for a location from climr (1981-2010 normals), then volume
clim <- ung_climate(lon = -105.5, lat = 54.1, elev = 500)
ung_volume("black spruce", age = 80, dd0 = clim$dd0, map = clim$map)

# How fragile is the answer? (volume change for +/- 100 degree-days or 100 mm)
ung_sensitivity("jack pine", age = 80, dd0 = 2200, map = 800)

ung_species()   # the 25 supported species
```

Many stands at once: pass vectors (or data frame columns) for `species`, `age`,
`dd0` and `map`; results come back as one row per stand.

## Climate inputs: read this first

* `dd0` is **degree-days above 0 °C** (ClimateNA/ClimateBC `DD_0`), **not**
  growing degree-days above 5 °C (`DD5`). Mixing them up gives wrong answers.
* `map` is mean annual precipitation in **mm**.
* Use long-term normals for the stand location, not one year's weather.
* `climr` has no native `DD_0`; `ung_climate()` derives it from the degree-day
  variables climr does provide. ClimateNA/ClimateBC users can pass their
  `DD_0` and `MAP` columns directly.

## Warnings

`ung_volume()` warns (and tells you how many rows are affected) when:

| Class | Trigger |
| --- | --- |
| `ung2009_warning_age` | age < 10 years, or outside the fitting-data age range |
| `ung2009_warning_climate` | `dd0` or `map` outside the fitting-data range |
| `ung2009_warning_sensitivity` | ±100 degree-days or ±100 mm changes volume by > 15 % |
| `ung2009_warning_models` | Nat1 and Nat2 volumes differ by > 30 % |
| `ung2009_warning_output` | volume or basal area exceeds the largest fitting-data value |
| `ung2009_warning_na` | missing inputs |

Silence one class with `withCallingHandlers()`, or everything with `warn = FALSE`.
The paper publishes fitting-data ranges only for black spruce, jack pine and
trembling aspen; other species are checked against the pooled range of those
three, which is approximate.

## Limitations (from the paper)

* Designed for **short-horizon (< 10 yr) increment prediction** for the Canadian
  National Forest Inventory. There is no stem-density safeguard, so use
  long-term projections with caution.
* Fitted to single-measurement plots dominated (≥ 75 % basal area) by one
  species; for mixed stands apply the model per species.
* Climate terms are **descriptive, not predictive**: do not use future climate
  projections to estimate climate-change impacts.
* Predictive ability for increments is moderate to poor, similar to provincial
  models.

## Provenance of parameters

Parameters were taken from the CTAE-derived implementation and are stored in
`data-raw/ung_parameters.csv` (built by `data-raw/build_parameters.R`). The
paper's parameter tables were not available in machine-readable form, so they
have been checked only for consistency with the fitting-data means in Table 2
(see `tests/`). Please compare against the published tables before relying on
them for a species you care about.

## Licence

MIT, Copyright His Majesty the King in Right of Canada, as represented by the
Minister of Natural Resources.
