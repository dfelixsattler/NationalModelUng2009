# Builds the example data used by the vignette:
#   data/example_stands.rda   - 10 made-up stands (location + up to 3 species)
#   data/example_climate.rda  - their dd0 and map from ClimateNA v7.60
#                               (1981-2010 averages)
#   inst/extdata/example_climate_climr.csv - the same from climr (kept for
#                               comparison; not used by the vignette)
#
# The stands are invented for illustration. Climate is stored because the
# vignette cannot run climr or ClimateNA while it is built.
# Run from the package root: source("data-raw/build_example_stands.R")

example_stands <- data.frame(
  stand_id = sprintf("S%02d", 1:10),
  lat  = c(54.10, 49.70, 49.90, 46.60, 45.60, 53.90, 51.00, 54.10, 55.70, 50.80),
  lon  = c(-105.50, -83.70, -74.40, -66.60, -78.40, -122.80, -118.20, -115.70,
           -97.90, -120.00),
  elev = c(500, 240, 400, 300, 420, 700, 600, 750, 220, 900),
  sp1  = c("jack pine", "black spruce", "black spruce", "balsam fir",
           "eastern white pine", "lodgepole pine", "western hemlock",
           "trembling aspen", "black spruce", "Douglas-fir"),
  sp2  = c(NA, NA, "balsam fir", "red spruce", "red pine", NA, "Douglas-fir",
           NA, NA, NA),
  sp3  = c(NA, NA, NA, "white birch", NA, NA, NA, NA, NA, NA),
  stringsAsFactors = FALSE
)

as_climate <- function(clim) {
  data.frame(id = clim$id, dd0 = round(clim$dd0), map = round(clim$map))
}

example_climate <- as_climate(NationalModelUng2009::ung_climate(
  example_stands$lon, example_stands$lat, example_stands$elev,
  id = example_stands$stand_id, source = "climatena",
  exe = "C:/ClimateNA_v760/ClimateNA_v7.60.exe"
))
save(example_stands, file = "data/example_stands.rda", compress = "bzip2")
save(example_climate, file = "data/example_climate.rda", compress = "bzip2")

utils::write.csv(
  as_climate(NationalModelUng2009::ung_climate(
    example_stands$lon, example_stands$lat, example_stands$elev,
    id = example_stands$stand_id
  )),
  "inst/extdata/example_climate_climr.csv", row.names = FALSE
)