# Reference values below were produced by the original (CTAE-derived) script
# Ung2009() for the same inputs.

test_that("predictions match the original implementation", {
  a <- ung_volume("POPU.TRE", 50, 2200, 750, warn = FALSE)
  expect_equal(c(a$H_Nat1, a$G_Nat1, a$V_Nat1, a$V_Nat2),
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
  expect_error(ung_volume("PICE.MAR", -1, 2000, 800), "negative")
  expect_error(ung_volume("PICE.MAR", 50, -5, 800), "negative")
  expect_error(ung_volume("PICE.MAR", "50", 2000, 800), "numeric")
  expect_error(ung_volume("PICE.MAR", 50, 2000, 800, nat1_bias_correction = NA),
               "nat1_bias_correction")
  expect_true(is.na(suppressWarnings(ung_volume("PICE.MAR", NA, 2000, 800)$V_Nat1)))
})

test_that("age 0 gives zero height, basal area and volume", {
  d <- ung_volume("PICE.MAR", c(0, 50), 2000, 800, warn = FALSE)
  expect_equal(unlist(d[1, c("H_Nat1", "G_Nat1", "V_Nat1", "V_Nat2")]),
               c(H_Nat1 = 0, G_Nat1 = 0, V_Nat1 = 0, V_Nat2 = 0))
  expect_gt(d$V_Nat2[2], 0)
})

test_that("Nat1 bias correction raises Nat1 volume only, by a factor above 1", {
  plain <- ung_volume("PICE.MAR", 80, 2079, 965, warn = FALSE)
  fixed <- ung_volume("PICE.MAR", 80, 2079, 965, nat1_bias_correction = TRUE,
                      warn = FALSE)
  p <- ung_parameters[ung_parameters$species == "PICE.MAR", ]
  factor <- 1 + (p$v31^2 * 2 * log(p$CDh) + p$v32^2 * 2 * log(p$CDg)) / 2
  expect_equal(fixed$V_Nat1, plain$V_Nat1 * factor)
  expect_equal(fixed$V_Nat2, plain$V_Nat2)
  expect_equal(fixed$H_Nat1, plain$H_Nat1)
  expect_true(attr(fixed, "nat1_bias_correction"))
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

test_that("ung_curve combines every species with every age", {
  d <- ung_curve(c("black spruce", "Douglas-fir"), age = 10:80, warn = FALSE)
  expect_s3_class(d, "ung_volume")
  expect_equal(nrow(d), 2 * 71)
  expect_equal(unique(d$species), c("PICE.MAR", "PSEU.MEN"))
  # species mean climate, different for each species
  expect_equal(length(unique(d$dd0)), 2)
  expect_equal(nrow(ung_curve("white spruce", 10:20, 2200, 600, warn = FALSE)), 11)
  expect_error(ung_curve(c("white spruce", "jack pine"), 10:20, dd0 = 1:3),
               "one value per species")
  # ung_volume matches row by row and the error points to ung_curve()
  expect_error(ung_volume(c("black spruce", "Douglas-fir"), age = 10:80),
               "ung_curve")
  expect_silent(plot(d))
})

test_that("ung_volume gives at most one warning, naming only actionable problems", {
  w <- character()
  withCallingHandlers(
    ung_volume(c("POPU.TRE", "PICE.MAR", "PINU.CON"), c(300, 80, 80),
               c(2200, 1000, 3500), c(750, 800, 2500)),
    warning = function(cnd) {
      w <<- c(w, conditionMessage(cnd))
      expect_s3_class(cnd, "ung2009_warning")
      invokeRestart("muffleWarning")
    }
  )
  expect_length(w, 1)
  expect_match(w, "older than", fixed = TRUE)
  expect_match(w, "ung_check()", fixed = TRUE)
  # A normal yield curve inside the data gives no warning at all
  expect_no_warning(ung_curve("PICE.MAR", seq(0, 150, by = 10), 2079, 965))
  expect_no_warning(ung_volume("POPU.TRE", 300, 2200, 750, warn = FALSE))
})

test_that("ung_check lists every check and flags the right rows", {
  ck <- ung_check(ung_volume("PICE.MAR", seq(0, 200, by = 10), 2079, 965,
                             warn = FALSE))
  expect_named(ck, c("check", "rows_flagged", "rows_total", "meaning"))
  expect_true(all(c("missing_input", "older_than_data", "climate_outside_data",
                    "output_beyond_data", "young_age", "long_horizon",
                    "sensitive_to_climate", "models_disagree") %in% ck$check))
  expect_equal(ck$rows_flagged[ck$check == "long_horizon"], 21)
  expect_equal(ck$rows_flagged[ck$check == "young_age"], 0)

  r <- ung_check(ung_volume("THUJ.OCC", c(5, 80), 2100, 800, warn = FALSE),
                 rows = TRUE)
  expect_equal(r$young_age, c(TRUE, FALSE))
  expect_true(r$sensitive_to_climate[2])
  expect_true(r$models_disagree[2])
  # A single stand is not a long projection
  expect_false(ung_check(ung_volume("PICE.MAR", 80, 2079, 965, warn = FALSE),
                         rows = TRUE)$long_horizon)
  expect_error(ung_check(data.frame(a = 1)), "species")
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
  expect_no_error(plot(ung_curve("PICE.MAR", 0:100, 2000, 800, warn = FALSE), what = "G"))
})

test_that("ung_yield_table gives a simple long or wide table, Nat2 by default", {
  # Default ages run to 250, past the oldest fitted black spruce plot
  expect_warning(tab <- ung_yield_table("PICE.MAR", dd0 = 2079, map = 965),
                 "older than")
  expect_named(tab, c("species", "dd0", "map", "age", "volume"))
  expect_equal(tab$age, seq(0, 250, by = 10))
  expect_equal(tab$volume[1], 0)
  expect_equal(attr(tab, "model"), "Nat2")
  expect_equal(tab$volume, ung_curve("PICE.MAR", seq(0, 250, by = 10), 2079, 965,
                                     model = "Nat2", warn = FALSE)$V_Nat2)

  w <- ung_yield_table(c("PICE.MAR", "PINU.BAN", "PICE.MAR"), age = c(0, 50, 100),
                       dd0 = c(2079, 2179, 1800), map = c(965, 772, 600),
                       model = "Nat1", format = "wide", warn = FALSE)
  expect_equal(nrow(w), 3)
  expect_named(w, c("species", "dd0", "map", "vol_0", "vol_50", "vol_100"))
  expect_equal(w$vol_50[2], ung_volume("PINU.BAN", 50, 2179, 772, warn = FALSE)$V_Nat1)

  u <- ung_yield_table("PINU.BAN", age = c(0, 60), dd0 = 2179, map = 772,
                       uncertainty = TRUE, n = 50, seed = 1, warn = FALSE)
  expect_named(u, c("species", "dd0", "map", "age", "volume", "lower", "upper"))
  expect_true(all(u$lower <= u$upper))
  uw <- ung_yield_table("PINU.BAN", age = c(0, 60), dd0 = 2179, map = 772,
                        uncertainty = TRUE, format = "wide", n = 50, seed = 1,
                        warn = FALSE)
  expect_equal(uw$statistic, c("volume", "lower", "upper"))
  expect_equal(uw$vol_60, c(u$volume[2], u$lower[2], u$upper[2]))
  expect_s3_class(ung_check(u), "data.frame")
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
