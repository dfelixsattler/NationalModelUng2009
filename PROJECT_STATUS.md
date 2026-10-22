# Project status: NationalModelUng2009

Status date: 2026-10-22. Package version: 0.1.0. Latest commit: `a7f6ea1`.
Quality gates at this date: `devtools::test()` gives 91 passing tests, 0 failures
and 1 skipped (an opt-in test that needs `climr`). `R CMD check` with vignettes
gives 0 errors, 0 warnings and 0 notes. Use R 4.5.3; R 4.6.0 was broken on the
development machine.

## 1. Purpose

An R package that implements the Nat1 and Nat2 national stand-volume models of
Ung, Bernier, Guo and Lambert (2009), *The Forestry Chronicle* 85(1): 57-64,
for 25 Canadian tree species.

* **Nat1** predicts dominant height (H), basal area (BA) and gross merchantable
  volume (V) in sequence. H and BA are functions of age, `dd0` and `map`.
  V is a function of ln(H) and ln(BA).
* **Nat2** predicts V directly from age, `dd0` and `map`.
* `dd0` is annual degree-days above 0 °C (the paper's `D0`). `map` is mean annual
  precipitation in mm.
* A Duan (1983) smearing factor is applied when each equation is back-transformed:
  `Y = exp(ln Y) * C_D`.

The package source of the model equations and parameters is the authors' own
spreadsheets and CSV files (kept in `myfiles/`; see section 5, item 1).

## 2. Major work completed

### Models and data

* `ung_volume()` implements Nat1 and Nat2 with vectorised, validated inputs.
  Species can be given as a common name, a scientific name or a code
  (`ung_species()`).
* **Parameters were verified cell by cell.** Nat1 (h, g, v coefficients and the three
  Duan factors) was checked against four CSV files. Nat2 was checked against sheet
  `V` of the authors' spreadsheet `Ung et al G&Y V, H and G models with
  DegreeDays.xls`. There were 0 differences.
* **The Nat1 volume equation was confirmed.** The authors' `system equations.xls`
  (sheet `Description`) gives `ln(V) = v30 + v31*ln(H) + v32*ln(G)` followed by
  the Duan factor. Volume therefore uses the uncorrected ln(H) and ln(G), and
  the Duan factor is applied to each output only. This is what the code does.
  (The sheet has two typos: `v22` for `v32`, and `ln(H)*Cd` for `exp(ln H)*Cd`.)
* **Per-species fitting-data envelope.** The dataset `ung_envelope` (25 species)
  holds the min, max, mean and SD of age, `dd0`, `map`, H, BA and V in the
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
* `ung_climate()` gets climate from `climr` (1981-2010 normals).
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

* Warnings, each with its own class (all inherit from `ung2009_warning`):
  `_age`, `_horizon`, `_climate`, `_sensitivity`, `_models`, `_output`, `_na`.
  Each can be silenced separately or with `warn = FALSE`.
* **Time-horizon caution.** The authors' limitation statement (designed for
  increments over very short, < 10 year intervals, with no safeguard such as an
  adjustment to merchantable stems per hectare) is quoted in the `ung_volume()`
  help page, the README and the vignette. The `ung2009_warning_horizon` warning
  fires when one call predicts the same species and climate over ages that span
  more than 10 years.
* `ung_sensitivity()`: percent change in volume for +/- 100 degree-days or
  +/- 100 mm.
* **Defaults for omitted climate:** if `dd0` or `map` is omitted, the package uses,
  for each species, the average `dd0` and average `map` of the plots the authors
  used to fit that species' model (`ung_envelope$dd0_mean`, `$map_mean`), with a
  message. The result is a typical stand of the species, not a site prediction.
* `ung_uncertainty()`: Monte Carlo climate-uncertainty fan (median and central
  interval) and its `plot()` method.
* `ung_curve()`: yield curves for several species (every species at every age).
  `ung_volume()` matches arguments row by row, so this is a separate function.
* `plot()` methods for `ung_volume` and `ung_uncertainty` results, with legends
  that show species, `dd0` and `map`.

### Documentation and tests

* Vignette `vignettes/ung-workflow.Rmd`: a six-step end-to-end example (location,
  model choice, climate values with three options, prediction, warnings, three
  checks). It uses the real ClimateNA values above.
* README, roxygen help pages and `ung_envelope` / `ung_parameters` provenance notes.
* Tests in `tests/testthat/` (volume, warnings, curves, uncertainty, ClimateNA
  conversion).

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
| An `NA` age stops with an unhelpful message ("missing value where TRUE/FALSE needed"). | `NA` inputs give `NA` predictions and an `ung2009_warning_na` warning. |
| Climate is not checked. A negative `GDD` is accepted (tested) and returns a number. | Negative or infinite `dd0`, `map` and non-positive ages stop with a clear message. |
| No check of the fitting range. The example in its comments predicts ages 1 to 300 at a climate far outside the fitting data for the species. | Per-species fitting envelope (`ung_envelope`) and warnings for age, climate, output size, high sensitivity to climate, Nat1 versus Nat2 disagreement and long age spans. |
| The result holds only `age`, `H`, `BA`, `V` and `V2`. It omits the species and the climate used, and the names are inconsistent (`V`, `V2`). | The result repeats `species`, `age`, `dd0` and `map`, and names columns by model (`V_Nat1`, `V_Nat2`, `H_Nat1`, `BA_Nat1`). It has a `plot()` method. |
| Species by code only. Parameters are typed into the function body. | Species by common name, scientific name or code (`ung_species()`). Parameters are a documented dataset with their source and verification (`ung_parameters`). |
| No documentation, tests or statement of the authors' limitations. | Help pages, a worked vignette and 91 tests. The authors' limitation statement (very short intervals, no safeguard on merchantable stems per hectare) is quoted, and it triggers a warning for long age spans. |
| No way to get climate. | `ung_climate()` (climr) and `ung_climate_from_climatena()` (local ClimateNA or ClimateBC), with the derivation of `dd0` and a documented warning that it is an approximation. |
| It needs the user to know which climate period to use. | The docs state one value per stand, constant with age, from a long-term normal, and that the paper does not give the period. |

### Problems in `NATGY.r`, and how the package resolves them

| Problem | Package |
| --- | --- |
| **The Monte Carlo draws are truncated at plus or minus 1 SD** (by rejection sampling). A normal variable truncated this way has a standard deviation of only about 0.54 of the stated SD, so the spread of the curves is understated by almost half. | `ung_uncertainty()` draws untruncated normal values (bounded at 0), so the spread matches the stated SD. The SD can be set (`sd_dd0`, `sd_map`), and the share of draws outside the fitting range is reported (`prop_outside`). |
| Degree-days and precipitation are drawn independently. | A correlation can be set (`cor`). The default is 0, which is stated. |
| The default SD is the among-plot spread (spatial variation). The script does not say that this is not the uncertainty of a site's climate. | The docs say that the default is spatial, not inter-annual and not product error, and that the interval is a climate-only interval, not a prediction interval. |
| The draw loops append values one at a time (`repeat`, `append`). They never end if an SD is missing (`NA`). | Draws are vectorised. `seed` makes them repeatable, and the user's random-number state is restored. |
| The result is raw curves. There is no interval (median, bounds) and no plot method. | The result has the median and a central interval (`interval`, default 90 %), and a `plot()` method. |
| Nat1 only. No Nat2, so there is no second model to compare. | Both models, and a warning when they disagree by more than 30 %. |
| Ages 1 to 100 by default, which includes ages under 10 where predictions are near zero and unreliable. | Warning for age under 10 and for ages outside the species' fitting range. |
| Hard-coded file paths (`C:/Juha/...`), `library(ggplot2)` at the top of the script, and parameters read from CSV files outside the repository. | An installable package with the parameters inside it, and no dependencies beyond base R (`climr` is optional). |
| A species missing from the climate file silently gives an empty result. | Species are validated against the 25 supported species. |

### Things the package adds that neither script has

* The per-species fitting envelope and the diagnostic warnings.
* `ung_sensitivity()`, which shows how much the volume changes for a 100
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
  Long-term yield curves are extrapolations. The model has no time-step argument,
  so the horizon warning can only detect age spans within a single call.
* Fitted to single-measurement temporary plots with a species making up at least
  75 % of basal area. For mixed stands, apply the model per species.
* The climate terms are descriptive. They must not be used with future climate
  projections to estimate climate-change impacts.
* Predictive ability for increments is moderate to poor, according to the paper.
* Volume is very sensitive to climate. For jack pine at age 80 (`dd0` 2200,
  `map` 800), a 100 degree-day error changes Nat1 volume by about 26 %.
* The uncertainty fan includes climate uncertainty only. It is not a prediction
  interval.

## 5. Outstanding issues

Ordered by priority.

1. **`myfiles/` and `Rplots.pdf` were tracked: now untracked (pending commit).**
   The folder (an email message, the authors' spreadsheets, `NATGY.r`, third-party
   CSV files) was committed by mistake. It has been removed from git tracking with
   `git rm -r --cached` and added to `.gitignore`, together with
   `tests/testthat/Rplots.pdf`. The files remain on disk, because
   `data-raw/build_envelope.R` and `build_parameters.R` read from `myfiles/`.
   The removal must still be committed. The earlier commits still contain the
   files in the history. Removing them from the history was judged not necessary.
   Decide whether the authors' files may be redistributed at all (see item 10).
2. **Resolved:** the stray `Rplots.pdf` (see item 1).
3. **The derived `dd0` has not been validated.** It is an approximation built from
   regression-based degree-day variables. It has not been compared with the climate
   values used to fit the models. The `ClimateMeanSD.csv` species means give a
   possible, indirect check.
4. **`ung_climate()` (climr) has not been compared with ClimateNA** for the same
   point. The user deferred this ("do not retry the climr validation"). Until it
   is done, the climr path is untested against a known result, and the opt-in test
   is skipped by default.
5. **Provenance of the Nat1 H and BA parameters.** The author's email says the H
   and G parameters in the later spreadsheet were re-estimated and differ slightly
   from those in the 2009 paper; only the volume model was published. The
   package's Nat1 values match four CSV files, and Nat2 matches the published
   volume sheet. Confirm with the authors which version of the H and BA
   parameters is intended. The `Parms` sheet of `system equations.xls` was not
   compared cell by cell with the package parameters.
6. **Warning thresholds are heuristics, not from the paper:** 15 % for
   sensitivity, 30 % for Nat1 versus Nat2 disagreement, and 10 years for age and
   horizon. They are set in `R/checks.R`. At species-mean climate and age 80, the
   sensitivity and model-disagreement warnings can legitimately fire, so users may
   see many warnings.
7. **No independent validation.** The package reproduces the published equations.
   There is no comparison with observed stand data. The only internal consistency
   check is Nat1 versus Nat2.
8. **Vignette not updated for the latest changes.** It does not mention
   `ung_curve()` or the wording of the typical-stand message. Its prose in
   steps 4 to 6 depends on exact numeric output (for example, "five warnings"
   in step 5, and Nat1 sensitivity above 15 and Nat2 below). Re-read it after any
   numeric change. The user planned to run it in RStudio.
9. **`ung_uncertainty()` pairs arguments row by row** (it has no equivalent of
   `ung_curve()`), so several species over a range of ages needs a loop or
   `expand.grid()`.
10. **Licence and attribution.** The package is MIT with a Crown copyright holder.
    Confirm that redistributing the authors' parameters is allowed and that the
    attribution in `DESCRIPTION` and the README is what the authors expect.
11. **Not set up:** continuous integration, a pkgdown site, and a release or CRAN
    submission. The version is 0.1.0. `climr` is in Suggests (it is slow to
    download).

## 6. Suggested next steps

1. Commit the removal of `myfiles/` and `Rplots.pdf` from tracking (outstanding item 1).
2. Run the vignette in RStudio and confirm its text matches its output.
3. Do the climr versus ClimateNA comparison at the example point, then update
   `ung_climate()` documentation with the result.
4. Ask the authors about items 3 and 5. Record their answers in `R/data.R`
   (provenance).
5. Optionally rename `GDD` to `dd0` in the user's external scripts
   (`Ung_stand_volume_function.R` and `NATGY.r`), to remove the naming confusion
   there. The comparison with the package is in section 3.
6. Decide whether to calibrate or justify the warning thresholds (item 6).
7. Consider an independent check against observed plot data, even a small one.

## 7. Where things are

| Path | Contents |
| --- | --- |
| `R/ung_volume.R` | `ung_volume()`, input checks, the equations (`.predict`) |
| `R/ung_curve.R` | `ung_curve()` |
| `R/ung_sensitivity.R` | `ung_sensitivity()` |
| `R/ung_uncertainty.R` | `ung_uncertainty()` and its plot method |
| `R/ung_climate.R` | `ung_climate()` (climr), `ung_climate_from_climatena()`, the `dd0` derivation |
| `R/checks.R`, `R/calibration.R` | Warning logic, thresholds, envelope lookup |
| `R/plot.R` | `plot.ung_volume()` |
| `R/data.R` | Documentation and provenance of `ung_parameters` and `ung_envelope` |
| `data/`, `data-raw/` | Datasets and the scripts that build them |
| `vignettes/ung-workflow.Rmd` | Worked example |
| `tests/testthat/` | Tests |
| `myfiles/` | Source spreadsheets, CSVs and scripts from the authors (see item 1) |
