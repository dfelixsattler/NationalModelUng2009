# Project status: NationalModelUng2009

Status date: 2026-10-22. Package version: 0.1.0. Latest commit: see `git log`
(commit IDs changed when the history was rewritten on 2026-10-22).
Quality gates at this date: `devtools::test()` gives 119 passing tests, 0 failures
and 1 skipped (an opt-in test that needs `climr`). `R CMD check` with vignettes
gives 0 errors, 0 warnings and 0 notes.
Use R 4.5.3; R 4.6.0 was broken on the development machine.

## 1. Purpose

An R package that implements the Nat1 and Nat2 national stand-volume models of
Ung, Bernier, Guo and Lambert (2009), *The Forestry Chronicle* 85(1): 57-64,
for 25 Canadian tree species. The main users are people who need a
volume-by-age curve, for example for the Carbon Budget Model (CBM), and
researchers who need a volume curve for an area of Canada. The package should
stay simple and use explicit, plain-English wording.

* **Nat1** predicts dominant height (H), basal area (G) and gross merchantable
  volume (V) in sequence. H and G are functions of age, `dd0` and `map`.
  V is a function of ln(H) and ln(G). The names H, G and V follow the paper and
  are used everywhere in the package (columns `H_Nat1`, `G_Nat1`, `V_Nat1`).
* **Nat2** predicts V directly from age, `dd0` and `map`.
* `dd0` is annual degree-days above 0 °C (the paper's `D0`). `map` is mean annual
  precipitation in mm.
* A Duan (1983) smearing factor is applied when each equation is back-transformed:
  `Y = exp(ln Y) * C_D`.

The package source of the model equations and parameters is the authors' own
spreadsheets and CSV files (kept in the untracked `myfiles/` folder).

## 2. Major work completed

### Decisions made in the review of 2026-10-22

* **Nat2 is the recommended model** and the default of `ung_yield_table()`.
* **Nat1 as published is biased low.** Its volume equation was fitted with
  measured H and G; in Nat1 they are predicted, and their error is not carried
  into the volume correction factor. At age 80 and species-mean climate, Nat2 is
  a median of about 20 % above Nat1 (higher for all 25 species). Nat1 stays
  available unchanged, with an opt-in second-order Taylor correction
  (`nat1_bias_correction = TRUE`, factor `1 + s2/2`,
  `s2 = v31^2 * 2 ln(CDh) + v32^2 * 2 ln(CDg)`, H and G errors assumed
  uncorrelated). The factor is 1.05 to 1.46 (median 1.20) and reduces the
  median Nat2/Nat1 gap to under 1 %.
* **Parameters are rounded to 4 decimal places in every source** (a few large
  values to 4 significant digits), and the unrounded estimates will not become
  available. The effect is documented prominently (README, `?ung_models`,
  `?ung_parameters`) and is included by default in the uncertainty interval of `ung_yield_table()`
  (`rounding = TRUE`). At age 80 and species-mean climate it is about 9 %
  (3 % to 16 %) for Nat1 and about 4 % (up to 9 %) for Nat2, as an SD.
* **Uncertainty is part of the main workflow** (`ung_yield_table(uncertainty =
  TRUE)`), not an add-on.
* **One warning per call, plus `ung_check()`.** Warnings that fire on almost
  every yield curve teach users to ignore warnings. `ung_yield_table()` gives at
  most one plain-English warning (class `ung2009_warning`), only for problems
  the user can act on: missing input, age above the fitting data, climate
  outside the fitting data, output larger than any fitting plot. The other
  cautions (young age, long horizon, sensitivity to climate, Nat1/Nat2
  disagreement) are listed on request by `ung_check()`.
* **Age 0 is allowed** and gives 0 for H, G and V, as CBM yield tables expect.
* Not to be done: contacting the authors (for unrounded parameters).

### Models and data

* The internal `ung_volume()` implements Nat1 and Nat2 with vectorised, validated inputs.
  Species can be given as a common name, a scientific name or a code
  (`ung_species()`).
* **Parameters were verified cell by cell.** Nat1 (h, g, v coefficients and the three
  Duan factors) was checked against four CSV files and against the `Parms` and
  `Fit` sheets of the authors' `system equations.xls` (all 25 species, 15
  coefficients and 75 Duan factors). Nat2 was checked against sheet
  `V` of the authors' spreadsheet `Ung et al G&Y V, H and G models with
  DegreeDays.xls`. There were 0 differences.
* **Nat1 H and G parameter version settled.** The H and G sheets of
  `Ung et al G&Y V, H and G models with DegreeDays.xls` hold a second,
  re-estimated set (each equation fitted on its own), which differs slightly.
  The package uses the set from the simultaneous system fit: it matches the
  authors' `system equations.xls`, the four CSV files, and Tables 4 and 5 of
  the paper (black spruce, jack pine, trembling aspen). No author contact is
  needed.
* **The Nat1 volume equation was confirmed.** The authors' `system equations.xls`
  (sheet `Description`) gives `ln(V) = v30 + v31*ln(H) + v32*ln(G)` followed by
  the Duan factor. Volume therefore uses the uncorrected ln(H) and ln(G), and
  the Duan factor is applied to each output only. This is what the code does.
  (The sheet has two typos: `v22` for `v32`, and `ln(H)*Cd` for `exp(ln H)*Cd`.)
* **Per-species fitting-data envelope.** The dataset `ung_envelope` (25 species)
  holds the min, max, mean and SD of age, `dd0`, `map`, H, G and V in the
  fitting data, taken from the `DATASUMMARY` sheet. It replaced an earlier pooled
  three-species range, which was wrong for most species. It is built by
  `data-raw/build_envelope.R`.

### Climate inputs

* **Corrected a naming error.** climr and ClimateNA `DD_0` is degree-days *below*
  0 °C, so it is not the models' `dd0`. `DD5` is also not `dd0`. The README, help
  pages and vignette now say this at the top.
* **Derived `dd0`:** `dd0 = (DD18 - DD_18) + 365*18 + DD_0`, where the
  ClimateNA names `DD18` (cooling degree-days above 18 °C), `DD_18` (below 18 °C)
  and `DD_0` (below 0 °C) are used. The user confirmed these variables exist in
  ClimateNA.
* `ung_climate()` gets climate from `climr` (default) or a local ClimateNA
  (`source = "climatena"`, Windows): 1981-2010 averages by default, or the
  average of the years given in `years`.
* `ung_climate_from_climatena()` converts a local ClimateNA or ClimateBC annual
  table to `dd0` and `map`. A **real run** of ClimateNA v7.60 was made for one
  point (lon -105.5, lat 54.1, elev 500 m): MAP 461, DD18 48, DD_18 6467, DD_0 2043,
  giving `dd0` = 2194. A monthly cross-check gave 2178 (a 16 degree-day, 0.7 %
  difference).
* **Climate period documented.** From the paper's text: one plot-level `D0` and `P`
  per plot, constant with age, derived from interpolated normals "to which
  inter-annual variability has been restored". The paper does not state the
  averaging period. The docs tell users to use a long-term normal and to report
  the period they used.

### Diagnostics and features

* `ung_yield_table()`: the main output for CBM users. Volume by age for one
  model (Nat2 by default), ages 0 to 250 by default, in a long layout (one row
  per age) or a wide layout (one row per curve, columns `vol_0`, `vol_10`, ...),
  with an optional uncertainty interval.
* `ung_check()`: a table of every caution, with the number of rows affected, or
  one TRUE/FALSE column per caution with `rows = TRUE`.
* At most one warning per call (see the decisions above). All warnings have the
  single class `ung2009_warning`; `warn = FALSE` turns them off.
* **Time-horizon caution.** The authors' limitation statement (designed for
  increments over very short, < 10 year intervals, with no safeguard such as an
  adjustment to merchantable stems per hectare) is quoted in the `?ung_models`
  help page, the README and the vignette. `ung_check()` flags it (`long_horizon`)
  when one species and climate are predicted over ages that span more than 10
  years.
* Climate sensitivity (internal, used by `ung_check()`): percent change in
  volume for +/- 100 degree-days or +/- 100 mm.
* **Defaults for omitted climate:** if `dd0` or `map` is omitted, the package uses,
  for each species, the average `dd0` and average `map` of the plots the authors
  used to fit that species' model (`ung_envelope$dd0_mean`, `$map_mean`), with a
  message. The result is a typical stand of the species, not a site prediction.
* `ung_yield_table(uncertainty = TRUE)`: Monte Carlo uncertainty interval
  (`lower`, `upper`) from climate uncertainty and parameter rounding (internal
  `.ung_uncertainty()`; options passed through `...`).
* `ung_yield_table()` combines every species with every age (internal
  `.ung_curve()`). `ung_volume()` (row by row) is internal; Nat1 height and
  basal area are available with `ung_yield_table(model = "Nat1", include_hg = TRUE)`.
* A `plot()` method for `ung_yield_table` results. The yield
  table has a `model` column, so Nat1 and Nat2 tables can be combined with
  `rbind()` and plotted together.

### Documentation and tests

* Vignette `vignettes/ung-workflow.Rmd`: an end-to-end example built around
  `ung_yield_table()`, uncertainty, `ung_check()` and the choice between Nat1
  and Nat2. Its text no longer depends on exact counts of warnings.
* README (plain-English sections on the model choice, rounding, uncertainty,
  climate names, the Duan factor, warnings and age 0), roxygen help pages and
  `ung_envelope` / `ung_parameters` provenance notes.
* Tests in `tests/testthat/` (volume, age 0, bias correction, warning and
  checks, yield table, curves, uncertainty with rounding, ClimateNA conversion).
* `data-raw/build_parameters.R` now reads `myfiles/Ung_stand_volume_function.R`
  (repo-relative) instead of a personal OneDrive path. Rebuilding gives an
  identical `ung_parameters`.

## 3. How the package improves on the earlier scripts

Two earlier R scripts were compared with the package:

* `Ung_stand_volume_function.R` (the `Ung2009()` function, taken from the CTAE
  package), called "the original script" below.
* `NATGY.r` (a Nat1-only script with Monte Carlo yield curves, from the authors).

A third file, `V_Huang_function_original.R`, is **not** an Ung implementation. It is
the Huang et al. (1994) tree-level taper and volume function for Alberta, so it
was not compared. Two observations for its owner: a comment says a 2 cm top
diameter inside bark is assumed, but the code uses `7`; and the function handles
one tree per call.

**Equations and parameters are identical.** All three give the same results for
the same inputs. This was tested: the hard-coded parameter tables of the original
script differ from `ung_parameters` by 0 (Nat1, Nat2 and all Duan factors, 25
species), and predictions for all 25 species, ages 5 to 200 and three climates
(14,700 rows) differ by 0. `NATGY.r` uses the same Nat1 equations and the same
uncorrected ln(H) and ln(G) in the volume equation. The package therefore changes
how the models are used, not what they compute.

### Problems in the original script (`Ung2009()`), and how the package resolves them

| Problem | Package |
| --- | --- |
| Arguments named `GDD` and `PREC`. `GDD` suggests growing degree-days above 5 °C, but the models need degree-days above 0 °C. | The argument is `dd0`. The help pages, README and vignette state that it is not `DD5` and not ClimateNA `DD_0`. |
| One species per call. With a vector of species it does not stop. It gives a warning and silently returns a **single row** (tested: two species gave one row). | Species are vectorised and matched row by row to age, `dd0` and `map`. `ung_curve()` combines species with ages. Mismatched lengths give an error that names the arguments. |
| An `NA` age stops with an unhelpful message ("missing value where TRUE/FALSE needed"). | `NA` inputs give `NA` predictions and a plain-English warning. |
| Climate is not checked. A negative `GDD` is accepted (tested) and returns a number. | Negative or infinite `dd0`, `map` and negative ages stop with a clear message. Age 0 gives volume 0. |
| No check of the fitting range. The example in its comments predicts ages 1 to 300 at a climate far outside the fitting data for the species. | Per-species fitting envelope (`ung_envelope`). One warning for age, climate or output outside the fitting data; `ung_check()` also flags high sensitivity to climate, Nat1 versus Nat2 disagreement, young ages and long age spans. |
| The result holds only `age`, `H`, `BA`, `V` and `V2`. It omits the species and the climate used, and the names are inconsistent (`V`, `V2`). | The result repeats `species`, `age`, `dd0` and `map`, and names columns by model (`V_Nat1`, `V_Nat2`, `H_Nat1`, `G_Nat1`). It has a `plot()` method. |
| Species by code only. Parameters are typed into the function body. | Species by common name, scientific name or code (`ung_species()`). Parameters are a documented dataset with their source and verification (`ung_parameters`). |
| No documentation, tests or statement of the authors' limitations. | Help pages, a worked vignette and 119 tests. The authors' limitation statement (very short intervals, no safeguard on merchantable stems per hectare) is quoted, and `ung_check()` flags long age spans. |
| No way to get climate. | `ung_climate()` (climr) and `ung_climate_from_climatena()` (local ClimateNA or ClimateBC), with the derivation of `dd0` and a documented warning that it is an approximation. |
| It needs the user to know which climate period to use. | The docs state one value per stand, constant with age, from a long-term normal, and that the paper does not give the period. |

### Problems in `NATGY.r`, and how the package resolves them

| Problem | Package |
| --- | --- |
| **The Monte Carlo draws are truncated at plus or minus 1 SD** (by rejection sampling). A normal variable truncated this way has a standard deviation of only about 0.54 of the stated SD, so the spread of the curves is understated by almost half. | `ung_uncertainty()` draws untruncated normal values (bounded at 0), so the spread matches the stated SD. The SD can be set (`sd_dd0`, `sd_map`), and the share of draws outside the fitting range is reported (`prop_outside`). |
| Degree-days and precipitation are drawn independently. | A correlation can be set (`cor`). The default is 0, which is stated. |
| The default SD is the among-plot spread (spatial variation). The script does not say that this is not the uncertainty of a site's climate. | The docs say that the default is spatial, not inter-annual and not product error, and that the interval covers climate and parameter rounding only, not the full range of real stands. |
| The draw loops append values one at a time (`repeat`, `append`). They never end if an SD is missing (`NA`). | Draws are vectorised. `seed` makes them repeatable, and the user's random-number state is restored. |
| The result is raw curves. There is no interval (median, bounds) and no plot method. | The result has the median and a central interval (`interval`, default 90 %), and a `plot()` method. |
| Nat1 only. No Nat2, so there is no second model to compare. | Both models; `ung_check()` flags disagreement of more than 30 %. Nat2 is recommended, and Nat1 has an optional bias correction. |
| Ages 1 to 100 by default, which includes ages under 10 where predictions are near zero and unreliable. | `ung_check()` flags ages under 10 or below the species' youngest fitted stand; ages above the oldest give a warning. |
| Hard-coded file paths (`C:/Juha/...`), `library(ggplot2)` at the top of the script, and parameters read from CSV files outside the repository. | An installable package with the parameters inside it, and no dependencies beyond base R (`climr` is optional). |
| A species missing from the climate file silently gives an empty result. | Species are validated against the 25 supported species. |

### Things the package adds that neither script has

* The per-species fitting envelope, the single warning and `ung_check()`.
* `ung_yield_table()` for CBM-style tables starting at age 0.
* The parameter-rounding uncertainty and the optional Nat1 bias correction.
* The `sensitive_to_climate` check of `ung_check()`, which flags how much the volume changes for a 100
  degree-day or 100 mm error in the climate values.
* Defaults for omitted climate (the average `dd0` and `map` of each species' fitting
  plots), with a message, for comparing species.
* Climate lookups, and the documentation of which climate variables are correct.

### Not improved, and shared with both scripts

* The equations are the published ones. The package does not correct or validate
  them against observed data.
* The Duan factors, and the uncorrected ln(H) and ln(G) in the volume equation, are
  the same as in both scripts (confirmed against the authors' `system equations.xls`).

## 4. Known limitations (by design or inherited from the paper)

* The models were built for increments over intervals shorter than 10 years.
  Long-term yield curves are extrapolations. `ung_check()` can only detect age
  spans within the data it is given.
* Fitted to single-measurement temporary plots with a species making up at least
  75 % of basal area. For mixed stands, apply the model per species.
* The climate terms are descriptive. They must not be used with future climate
  projections to estimate climate-change impacts.
* Predictive ability for increments is moderate to poor, according to the paper.
* Volume is very sensitive to climate. For jack pine at age 80 (`dd0` 2200,
  `map` 800), a 100 degree-day error changes Nat1 volume by about 26 %.
* The parameters are rounded (section 2). This cannot be fixed.
* The uncertainty interval covers climate and parameter rounding only. Nat1
  standard errors exist in `Parms.csv`, but there are none for Nat2 and no
  parameter correlations, so parameter estimation error is not included.
* The Nat1 bias correction assumes uncorrelated H and G errors and roughly
  normal log-scale errors. It is the package's addition, not the authors'.

## 5. Outstanding issues

Ordered by priority.

1. **The derived `dd0` has not been validated** (on hold by decision). It is an
   approximation built from regression-based degree-day variables and has not
   been compared with the climate values used to fit the models.
2. **`ung_climate()` (climr) has not been compared with ClimateNA** for the same
   point (on hold by decision). The opt-in test is skipped by default.
3. **Thresholds are rules of thumb, not from the paper** (on hold by decision):
   15 % for sensitivity, 30 % for Nat1 versus Nat2, 10 years for young ages and
   for the horizon. They are set in `R/checks.R` and now affect only
   `ung_check()`, not warnings.
4. **No independent validation** against observed stand data.
5. **Licence and attribution.** Confirm that redistributing the authors'
   parameters is allowed and that the attribution is what the authors expect.
6. **Not set up:** continuous integration, a pkgdown site, and a release. The
   version is 0.1.0. `climr` is in Suggests.

Resolved on 2026-10-22:

* `myfiles/` and `Rplots.pdf` were removed from the whole git history
  (`git filter-branch`) and the rewritten `main` was force-pushed. All commit
  IDs changed; other clones must be re-cloned. GitHub may keep cached copies of
  old commits until its own clean-up.
* The Nat1 H and G parameter version (see section 2, *Models and data*).

## 6. Suggested next steps

1. Run the vignette in RStudio and confirm its text reads well with its output.
2. When time allows, the items on hold: `dd0` and climr validation, and the
   thresholds.
3. Consider an independent check against observed plot data, even a small one.

## 7. Where things are

| Path | Contents |
| --- | --- |
| `R/ung_volume.R` | the `?ung_models` help page, the internal `ung_volume()`, input checks, the equations (`.predict`), the main documentation of model choice, rounding, Duan factor, climate names |
| `R/ung_yield_table.R` | `ung_yield_table()` (long and wide CBM-style tables) |
| `R/ung_curve.R` | `.ung_curve()` (internal: every species at every age) |
| `R/checks.R` | `ung_check()`, the single warning, thresholds |
| `R/calibration.R` | Envelope lookup and the warning helper |
| `R/ung_sensitivity.R` | `.ung_sensitivity()` (internal, used by `ung_check()`) |
| `R/ung_uncertainty.R` | `.ung_uncertainty()` (internal) and the rounding draws |
| `R/ung_climate.R` | `ung_climate()` (climr or ClimateNA), `ung_climate_from_climatena()`, the `dd0` derivation |
| `R/plot.R` | `plot.ung_yield_table()` |
| `R/data.R` | Documentation and provenance of `ung_parameters`, `ung_envelope`, `example_stands` and `example_climate` |
| `data/`, `data-raw/` | Datasets and the scripts that build them (they read the untracked `myfiles/`) |
| `vignettes/ung-workflow.Rmd` | Worked example |
| `tests/testthat/` | Tests |
| `myfiles/` | Source spreadsheets, CSVs and scripts from the authors (untracked) |