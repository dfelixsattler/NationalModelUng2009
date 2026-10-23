# Builds the example files used by the vignette:
#   inst/extdata/example_stands.csv            - 10 made-up stands (location + leading species)
#   inst/extdata/example_climate_climr.csv     - their dd0 and map from climr
#   inst/extdata/example_climate_climatena.csv - their dd0 and map from ClimateNA
#
# The stands are invented for illustration. Species are written in short
# codes, as many inventories do, so the vignette can show how to translate
# them into names the package accepts.
#
# Climate: 1981-2010 normals from climr (ung_climate()) and from ClimateNA
# v7.60 (ung_climate(source = "climatena")). They are stored because the vignette cannot
# run climr or ClimateNA while it is built. climr needs its database server,
# which some VPNs block.
# Run from the package root: source("data-raw/build_example_stands.R")

stands <- data.frame(
  stand_id = sprintf("S%02d", 1:10),
  lat  = c(54.10, 49.70, 49.90, 46.60, 45.60, 53.90, 51.00, 54.10, 55.70, 50.80),
  lon  = c(-105.50, -83.70, -74.40, -66.60, -78.40, -122.80, -118.20, -115.70,
           -97.90, -120.00),
  elev = c(500, 240, 400, 300, 420, 700, 600, 750, 220, 900),
  sp1  = c("PJ", "SB", "SB", "BF", "PW", "PL", "HW", "AW", "SB", "FD"),
  sp2  = c("",   "",   "BF", "RS", "PR", "",   "FD", "",   "",   ""),
  sp3  = c("",   "",   "",   "BW", "",   "",   "",   "",   "",   ""),
  stringsAsFactors = FALSE
)
dir.create("inst/extdata", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(stands, "inst/extdata/example_stands.csv", row.names = FALSE)

save_climate <- function(clim, file) {
  out <- data.frame(id = clim$id, dd0 = round(clim$dd0),
                    map = round(clim$map))
  utils::write.csv(out, file, row.names = FALSE)
}

save_climate(
  NationalModelUng2009::ung_climate(stands$lon, stands$lat, stands$elev,
                                    id = stands$stand_id),
  "inst/extdata/example_climate_climr.csv"
)
save_climate(
  NationalModelUng2009::ung_climate(
    stands$lon, stands$lat, stands$elev, id = stands$stand_id,
    source = "climatena", exe = "C:/ClimateNA_v760/ClimateNA_v7.60.exe"
  ),
  "inst/extdata/example_climate_climatena.csv"
)