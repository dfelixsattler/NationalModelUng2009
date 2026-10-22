test_that("ClimateNA/ClimateBC output is converted to dd0 and map", {
  # real ClimateNA 7.60 output, Normal_1981_2010, lon -105.5, lat 54.1, elev 500
  real <- data.frame(id2 = "stand1", MAP = 461, DD18 = 48, DD_18 = 6467, DD_0 = 2043)
  expect_equal(ung_climate_from_climatena(real, id = "id2", quiet = TRUE)$dd0, 2194)
  x <- data.frame(id2 = c("a", "b"), MAP = c(480, 900),
                  DD18 = c(30, 0), DD_18 = c(5800, 6100), DD_0 = c(1100, 1500))
  expect_message(r <- ung_climate_from_climatena(x, id = "id2"), "DD18, DD_18")
  expect_named(r, c("id", "dd0", "map"))
  expect_equal(r$id, c("a", "b"))
  expect_equal(r$map, c(480, 900))
  expect_equal(r$dd0, c(30 - 5800 + 365 * 18 + 1100, 0 - 6100 + 365 * 18 + 1500))
  # a value of dd0 that goes straight into the model
  expect_no_error(ung_volume("PICE.GLA", 80, r$dd0[1], r$map[1], warn = FALSE))
})

test_that("climatena conversion matches names loosely and rejects bad input", {
  x <- data.frame(map = 480, dd18 = 30, dd_18 = 5800, dd_0 = 1100)
  expect_equal(ung_climate_from_climatena(x, quiet = TRUE)$dd0, 1900)
  expect_error(ung_climate_from_climatena(x[, c("map", "dd18")], quiet = TRUE),
               "DD_18, DD_0")
  expect_error(ung_climate_from_climatena(x, id = "nope", quiet = TRUE), "`id`")
  expect_error(ung_climate_from_climatena("a"), "data.frame")
  neg <- transform(x, dd_0 = -1100)
  expect_ung_warning(ung_climate_from_climatena(neg, quiet = TRUE),
                     "ung2009_warning")
})
