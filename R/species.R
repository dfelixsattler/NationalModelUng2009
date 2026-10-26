#' Species supported by the Ung et al. (2009) national models
#'
#' Returns the 25 species for which Ung et al. (2009) published parameters,
#' with the code used internally by the models, the scientific name and the
#' common name. Any of the three can be used as the `species` argument of
#' [ung_yield_table()].
#'
#' @return A data.frame with columns `code`, `scientific` and `common`.
#' @export
#' @examples
#' ung_species()
ung_species <- function() {
  data.frame(
    code = c("ABIE.BAL", "ABIE.LAS", "ACER.RUB", "ACER.SAC", "BETU.ALL",
             "BETU.PAP", "FAGU.GRA", "LARI.LAR", "LARI.OCC", "PICE.ENG",
             "PICE.GLA", "PICE.MAR", "PICE.RUB", "PINU.BAN", "PINU.CON",
             "PINU.RES", "PINU.STR", "POPU.BAL", "POPU.GRA", "POPU.TRE",
             "PSEU.MEN", "QUER.RUB", "THUJ.OCC", "TSUG.CAN", "TSUG.HET"),
    scientific = c("Abies balsamea", "Abies lasiocarpa", "Acer rubrum",
                   "Acer saccharum", "Betula alleghaniensis",
                   "Betula papyrifera", "Fagus grandifolia", "Larix laricina",
                   "Larix occidentalis", "Picea engelmannii", "Picea glauca",
                   "Picea mariana", "Picea rubens", "Pinus banksiana",
                   "Pinus contorta", "Pinus resinosa", "Pinus strobus",
                   "Populus balsamifera", "Populus grandidentata",
                   "Populus tremuloides", "Pseudotsuga menziesii",
                   "Quercus rubra", "Thuja occidentalis", "Tsuga canadensis",
                   "Tsuga heterophylla"),
    common = c("balsam fir", "subalpine fir", "red maple", "sugar maple",
               "yellow birch", "white birch", "American beech", "tamarack",
               "western larch", "Engelmann spruce", "white spruce",
               "black spruce", "red spruce", "jack pine", "lodgepole pine",
               "red pine", "eastern white pine", "balsam poplar",
               "largetooth aspen", "trembling aspen", "Douglas-fir",
               "red oak", "eastern white cedar", "eastern hemlock",
               "western hemlock"),
    stringsAsFactors = FALSE
  )
}

# Convert user-supplied species labels (code, scientific or common name, any
# case) to the model codes; stops with a helpful message on unknown labels.
.resolve_species <- function(species) {
  if (is.factor(species)) species <- as.character(species)
  if (!is.character(species) || length(species) == 0L || anyNA(species)) {
    stop("`species` must be a non-empty character vector without NA values. ",
         "See ung_species() for valid options.", call. = FALSE)
  }

  tbl <- ung_species()
  key <- function(x) gsub("[^a-z]", "", tolower(x))
  lookup <- c(
    stats::setNames(tbl$code, key(tbl$code)),
    stats::setNames(tbl$code, key(tbl$scientific)),
    stats::setNames(tbl$code, key(tbl$common))
  )

  codes <- unname(lookup[key(species)])
  if (anyNA(codes)) {
    bad <- unique(species[is.na(codes)])
    stop("unknown species: ", paste0("'", bad, "'", collapse = ", "),
         ". Use a code, scientific name or common name from ung_species().",
         call. = FALSE)
  }
  codes
}
