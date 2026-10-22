# Reference values below were produced by the original (CTAE-derived) script
# Ung2009() for the same inputs.

test_that("predictions match the original implementation", {
  a <- ung_volume("POPU.TRE", 50, 2200, 750, warn = FALSE)
  expect_equal(c(a$H_Nat1, a$BA_Nat1, a$V_Nat1, a$V_Nat2),
               c(17.8, 24.0, 162.5, 190.3), tolerance = 0.01)

  b <- ung_volume("PICE.MAR", 80, 2100, 800, warn = FALSE)
  expect_equal(c(b$V_Nat1, b$V_Nat2), c(108, 120), tolerance = 0.01)
})

test_that("predictions are close to the fitting-data means of Table 2", {
  # Mean age/climate/volume of black spruce, jack pine, trembling aspen
  d <- ung_volume(c("PICE.MAR", "PINU.BAN", "POPU.TRE"),
                  c(80.5, 53.6, 59.1), c(2079, 2179, 2212), c(965, 772, 743),
                  warn = FALSE)
  observed <- c(107.2, 132.8, 214.2)
  expect_equal(d$V_Nat1, observed, tolerance = 0.15)
  expect_equal(d$V_Nat2, observed, tolerance = 0.15)
})

test_that("species can be given as code, scientific or common name", {
  ref <- ung_volume("PICE.MAR", 80, 2000, 800, warn = FALSE)
  expect_equal(ung_volume("Picea mariana", 80, 2000, 800, warn = FALSE), ref)
  expect_equal(ung_volume("Black Spruce", 80, 2000, 800, warn = FALSE), ref)
  expect_error(ung_volume("oak", 80, 2000, 800), "unknown species")
  expect_equal(nrow(ung_species()), 25)
})

test_that("inputs are recycled, and bad inputs are rejected", {
  d <- ung_volume("PICE.MAR", 10:19, 2000, 800, model = "Nat2", warn = FALSE)
  expect_equal(nrow(d), 10)
  expect_named(d, c("species", "age", "dd0", "map", "V_Nat2"))
  expect_error(ung_volume("PICE.MAR", 1:3, 2000:2001, 800), "length")
  expect_error(ung_volume("PICE.MAR", 0, 2000, 800), "greater than 0")
  expect_error(ung_volume("PICE.MAR", 50, -5, 800), "negative")
  expect_error(ung_volume("PICE.MAR", "50", 2000, 800), "numeric")
  expect_true(is.na(suppressWarnings(ung_volume("PICE.MAR", NA, 2000, 800)$V_Nat1)))
})

test_that("a typical in-range stand gives no warnings", {
  expect_no_warning(ung_volume("PICE.MAR", 80, 2079, 965))
})

test_that("fitting-data envelope is per species and internally consistent", {
  env <- ung_envelope
  expect_equal(nrow(env), 25)
  expect_setequal(env$species, ung_parameters$species)
  expect_true(all(env$v_max > env$v_mean & env$v_mean > env$v_min))
  # a coastal species is checked against its own range, not a pooled one
  expect_gt(env$v_max[env$species == "PSEU.MEN"], 1000)
  e <- env[env$species == "PSEU.MEN", ]
  expect_no_warning(ung_volume("PSEU.MEN", 100, e$dd0_mean, e$map_mean))
})

test_that("diagnostic warnings fire with their own classes", {
  expect_ung_warning(ung_volume("POPU.TRE", 5, 2200, 750), "ung2009_warning_age")
  expect_ung_warning(ung_volume("POPU.TRE", 300, 2200, 750), "ung2009_warning_age")
  expect_ung_warning(ung_volume("PICE.MAR", 80, 1000, 800), "ung2009_warning_climate")
  expect_ung_warning(ung_volume("THUJ.OCC", 80, 2100, 800), "ung2009_warning_sensitivity")
  expect_ung_warning(ung_volume("THUJ.OCC", 80, 2100, 800), "ung2009_warning_models")
  expect_ung_warning(ung_volume("PINU.CON", 80, 3500, 2500), "ung2009_warning_output")
  expect_ung_warning(ung_volume("POPU.TRE", NA, 2200, 750), "ung2009_warning_na")
  # Specific classes can be silenced individually, and warn = FALSE silences all
  expect_no_warning(ung_volume("POPU.TRE", 5, 2200, 750, warn = FALSE))
})

test_that("horizon warning flags yield curves but not single ages or stands", {
  curve_ages <- seq(20, 100, by = 20)
  expect_ung_warning(ung_volume("PICE.MAR", curve_ages, 2100, 800),
                     "ung2009_warning_horizon")
  # A span of exactly 10 years is within the design horizon
  expect_no_warning(ung_volume("PICE.MAR", c(70, 80), 2100, 800))
  # Different stands (different climate) are not one projection
  expect_no_warning(ung_volume("PICE.MAR", c(40, 90), c(2000, 2200), 800))
  expect_no_warning(ung_volume("PICE.MAR", curve_ages, 2100, 800, warn = FALSE))
})

test_that("sensitivity table has the documented structure and values", {
  s <- ung_sensitivity("THUJ.OCC", 80, 2100, 800)
  expect_equal(s$model, c("Nat1", "Nat2"))
  expect_equal(s$max_change_pct, pmax(s$dd0_change_pct, s$map_change_pct))
  expect_gt(s$max_change_pct[s$model == "Nat1"], 15)
  # Near-empty stands give NA rather than a meaningless relative change
  expect_true(is.na(ung_sensitivity("POPU.TRE", 1, 2200, 750, model = "Nat2")$max_change_pct))
})

test_that("plot method runs for one and several curves", {
  d <- ung_volume(rep(c("PICE.MAR", "PINU.BAN"), 3), rep(c(20, 60, 100), each = 2),
                  2100, 800, warn = FALSE)
  pdf(NULL)
  on.exit(dev.off())
  expect_no_error(plot(d))
  expect_error(plot(ung_volume("PICE.MAR", 50, 2000, 800, model = "Nat2", warn = FALSE), what = "H"),
               "no H predictions")
})

test_that("ung_climate returns dd0 and map from climr (opt-in, needs network)", {
  skip_on_cran()
  skip_if_not_installed("climr")
  skip_if(Sys.getenv("UNG2009_TEST_CLIMR") != "true", "set UNG2009_TEST_CLIMR=true to run")
  clim <- ung_climate(-105.5, 54.1, 500, quiet = TRUE)
  expect_named(clim, c("id", "lon", "lat", "elev", "dd0", "map"))
  expect_true(clim$dd0 > 1500 && clim$dd0 < 2800)
  expect_true(clim$map > 300 && clim$map < 800)
})

test_that("ung_climate validates inputs before calling climr", {
  skip_if_not_installed("climr")
  expect_error(ung_climate(c(-105, -106), 54, 500), "equal length")
  expect_error(ung_climate(-105, 54, NA_real_), "missing")
})
