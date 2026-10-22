# One-off script: builds the per-species calibration envelope (mean, SD, min and
# max of age, D0, P, H, G and V in the fitting data) from the DATASUMMARY sheet of
# "Ung et al G&Y V, H and G models with DegreeDays.xls" supplied by the model
# developers. Writes data-raw/ung_envelope.csv and data/ung_envelope.rda.
# Run from the package root: source("data-raw/build_envelope.R")

src <- "myfiles/Ung et al G&Y V, H and G models with DegreeDays.xls"
raw <- as.data.frame(readxl::read_excel(src, sheet = "DATASUMMARY", col_names = FALSE,
                                        .name_repair = "minimal"))
raw <- raw[-1, ]                                  # drop the header row
stopifnot(nrow(raw) == 50)

nums <- function(x) {
  p <- strsplit(trimws(gsub("[()\u00b1;]", " ", x)), "\\s+")[[1]]
  as.numeric(p[nzchar(p)])
}

vars <- c(h = 3, ba = 4, v = 5, age = 6, dd0 = 7, map = 8)   # sheet columns
sp_map <- stats::setNames(NationalModelUng2009::ung_species()$code,
                          NationalModelUng2009::ung_species()$scientific)

rows <- lapply(seq(1, 49, by = 2), function(i) {
  pair <- raw[i:(i + 1), ]
  # Each species spans two rows (means and ranges); the species name and the
  # plot count N can sit on either row, so identify rows by content.
  is_mean <- !is.na(pair[[2]])
  is_range <- grepl("^\\s*\\(", pair[[3]])
  stopifnot(sum(is_mean) == 1, sum(is_range) == 1)
  name <- trimws(stats::na.omit(unlist(pair[[1]]))[1])
  out <- list(species = unname(sp_map[name]), n = as.integer(pair[[2]][is_mean]))
  for (v in names(vars)) {
    m <- nums(pair[[vars[[v]]]][is_mean])
    r <- nums(pair[[vars[[v]]]][is_range])
    out[[paste0(v, "_mean")]] <- m[1]; out[[paste0(v, "_sd")]] <- m[2]
    out[[paste0(v, "_min")]] <- r[1];  out[[paste0(v, "_max")]] <- r[2]
  }
  as.data.frame(out, stringsAsFactors = FALSE)
})
ung_envelope <- do.call(rbind, rows)
ung_envelope <- ung_envelope[order(ung_envelope$species), ]
rownames(ung_envelope) <- NULL

stopifnot(!anyNA(ung_envelope), nrow(ung_envelope) == 25,
          setequal(ung_envelope$species, NationalModelUng2009::ung_species()$code),
          all(ung_envelope$dd0_min < ung_envelope$dd0_mean & ung_envelope$dd0_mean < ung_envelope$dd0_max),
          all(ung_envelope$map_min < ung_envelope$map_mean & ung_envelope$map_mean < ung_envelope$map_max),
          all(ung_envelope$age_min < ung_envelope$age_mean & ung_envelope$age_mean < ung_envelope$age_max))

utils::write.csv(ung_envelope, "data-raw/ung_envelope.csv", row.names = FALSE)
save(ung_envelope, file = "data/ung_envelope.rda", compress = "bzip2", version = 2)
