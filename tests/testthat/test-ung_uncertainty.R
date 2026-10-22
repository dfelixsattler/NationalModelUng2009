test_that("species-mean climate is used when dd0 and map are omitted", {
  e <- ung_envelope[ung_envelope$species == "PICE.MAR", ]
  expect_message(d <- ung_volume("PICE.MAR", 80), "average")
  expect_equal(d$dd0, e$dd0_mean)
  expect_equal(d$map, e$map_mean)
  expect_equal(d[, c("V_Nat1", "V_Nat2")],
               ung_volume("PICE.MAR", 80, e$dd0_mean, e$map_mean)[, c("V_Nat1", "V_Nat2")])
  # only the missing one is defaulted; other species get their own mean
  expect_message(d2 <- ung_volume(c("PICE.MAR", "PSEU.MEN"), 80, dd0 = 2000), "`map`")
  expect_equal(d2$dd0, c(2000, 2000))
  expect_equal(d2$map, ung_envelope$map_mean[match(c("PICE.MAR", "PSEU.MEN"), ung_envelope$species)])
  # explicit climate gives no message, and warn = FALSE silences it
  expect_no_message(ung_volume("PICE.MAR", 80, 2000, 900))
  expect_no_message(ung_volume("PICE.MAR", 80, warn = FALSE))
  # defaults lie inside each species' own fitting range, so no warning at all
  expect_no_warning(suppressMessages(ung_volume(ung_species()$code, 80)))
})

test_that("ung_uncertainty returns a reproducible, ordered fan", {
  a <- ung_uncertainty("PICE.MAR", c(40, 80), 2000, 900, n = 200, seed = 1, warn = FALSE)
  b <- ung_uncertainty("PICE.MAR", c(40, 80), 2000, 900, n = 200, seed = 1, warn = FALSE)
  expect_equal(a, b)
  expect_equal(nrow(a), 4)
  expect_equal(a$model, rep(c("Nat1", "Nat2"), 2))
  expect_true(all(a$lower <= a$median & a$median <= a$upper))
  expect_true(all(a$prop_outside >= 0 & a$prop_outside <= 1))
  central <- ung_volume("PICE.MAR", c(40, 80), 2000, 900, warn = FALSE)
  expect_equal(a$volume[a$model == "Nat1"], central$V_Nat1)
  expect_equal(a$volume[a$model == "Nat2"], central$V_Nat2)
})

test_that("zero SD collapses the fan; larger SD widens it; seed is restored", {
  z <- ung_uncertainty("PINU.BAN", 80, 2200, 800, n = 50, sd_dd0 = 0, sd_map = 0,
                       rounding = FALSE, seed = 2, warn = FALSE)
  expect_equal(z$lower, z$volume)
  expect_equal(z$upper, z$volume)
  # Rounding alone gives a small but non-zero spread around the central value
  r <- ung_uncertainty("PINU.BAN", 80, 2200, 800, n = 500, sd_dd0 = 0, sd_map = 0,
                       seed = 2, warn = FALSE)
  expect_true(all(r$upper > r$lower))
  expect_true(all(r$lower < r$volume & r$volume < r$upper))
  expect_true(all((r$upper - r$lower) / r$volume < 0.5))
  narrow <- ung_uncertainty("PINU.BAN", 80, 2200, 800, n = 500, sd_dd0 = 20, sd_map = 20,
                            seed = 2, warn = FALSE)
  wide <- ung_uncertainty("PINU.BAN", 80, 2200, 800, n = 500, sd_dd0 = 200, sd_map = 200,
                          seed = 2, warn = FALSE)
  expect_gt(wide$upper[1] - wide$lower[1], narrow$upper[1] - narrow$lower[1])

  set.seed(99); r1 <- runif(1)
  set.seed(99)
  ung_uncertainty("PINU.BAN", 80, 2200, 800, n = 20, seed = 5, warn = FALSE)
  expect_equal(runif(1), r1)
})

test_that("ung_uncertainty uses species-mean climate and SDs by default, and validates", {
  e <- ung_envelope[ung_envelope$species == "POPU.TRE", ]
  f <- suppressMessages(ung_uncertainty("POPU.TRE", 60, n = 50, seed = 3, model = "Nat2"))
  expect_equal(f$dd0, e$dd0_mean)
  expect_equal(f$sd_dd0, e$dd0_sd)
  expect_equal(f$sd_map, e$map_sd)
  expect_error(ung_uncertainty("POPU.TRE", 60, n = 5), "`n`")
  expect_error(ung_uncertainty("POPU.TRE", 60, cor = 1), "`cor`")
  expect_error(ung_uncertainty("POPU.TRE", 60, interval = 1), "`interval`")
  expect_error(ung_uncertainty("POPU.TRE", c(60, 70), sd_dd0 = c(1, 2, 3)), "`sd_dd0`")
  expect_error(ung_uncertainty("POPU.TRE", 60, sd_map = -1), "`sd_map`")
})

test_that("plot method for the uncertainty fan runs", {
  f <- ung_uncertainty(rep(c("PICE.MAR", "PINU.BAN"), 3), rep(c(20, 60, 100), each = 2),
                       2100, 800, n = 50, seed = 1, warn = FALSE)
  pdf(NULL)
  on.exit(dev.off())
  expect_no_error(plot(f))
})
