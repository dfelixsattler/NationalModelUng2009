# One-off script: extracts the Ung et al. (2009) parameter tables from the R
# implementation supplied with the developers' files and writes
# data/ung_parameters.rda plus a CSV for review.
# Run from the package root: source("data-raw/build_parameters.R")
#
# Notes on the source values:
# * Every parameter was published with 4 decimal places (a few large rate terms,
#   e.g. 182, -757, -159.3, with 4 significant digits). The unrounded estimates
#   are not available; ung_uncertainty() propagates the rounding error.
# * Trembling aspen (POPU.TRE) v31 is 0.9262 in every developer file but 0.9263
#   in Table 4 of the paper. The file value is kept; the difference changes
#   volume by about 0.01 %.
# * myfiles/ is not tracked in git (it holds the developers' files), so this
#   script can only be rerun on a machine that has a copy.

src <- "myfiles/Ung_stand_volume_function.R"
if (!file.exists(src)) stop("Source file not found: ", src)
txt <- readLines(src, warn = FALSE)

# Pull the rows of a tibble::tribble() block that starts at the line matching `start`
read_tribble <- function(start) {
  i0 <- grep(start, txt, fixed = TRUE)[1]
  i1 <- i0 + which(grepl("^\\s*\\)\\s*$", txt[(i0 + 1):length(txt)]))[1]
  body <- gsub("^\\s+|,\\s*$", "", txt[(i0 + 1):(i1 - 1)])
  body <- gsub("~", "", body, fixed = TRUE)
  body <- gsub("\"", "", body, fixed = TRUE)
  utils::read.csv(text = body, stringsAsFactors = FALSE)
}

p1 <- read_tribble("P <- tibble::tribble(")
p2 <- read_tribble("P2 <- tibble::tribble(")
stopifnot(nrow(p1) == 25, nrow(p2) == 25, identical(p1$Species, p2$Species))

# Nat2's correction factor "Cd" is renamed to avoid confusion with Nat1's CDh/CDg/CDv
names(p2)[names(p2) == "Cd"] <- "CDv2"
ung_parameters <- merge(p1, p2, by = "Species", sort = FALSE)
names(ung_parameters)[1] <- "species"
ung_parameters <- ung_parameters[order(ung_parameters$species), ]
rownames(ung_parameters) <- NULL

stopifnot(!anyNA(ung_parameters), ncol(ung_parameters) == 26)
utils::write.csv(ung_parameters, "data-raw/ung_parameters.csv", row.names = FALSE)
save(ung_parameters, file = "data/ung_parameters.rda", compress = "bzip2", version = 2)
