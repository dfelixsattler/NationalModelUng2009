# Monte Carlo 90 % interval of predicted volume from climate uncertainty. Used
# by ung_yield_table(uncertainty = TRUE); see the *Uncertainty interval*
# section of ?ung_yield_table. `n` is kept only so tests can run fewer draws.
.ung_uncertainty <- function(species, age, dd0 = NULL, map = NULL,
                            model = c("both", "Nat1", "Nat2"),
                            n = 1000, sd_dd0 = NULL, sd_map = NULL,
                            nat1_bias_correction = FALSE, seed = NULL,
                            warn = TRUE) {
  model <- match.arg(model)
  .check_logical(nat1_bias_correction, "nat1_bias_correction")
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 10) {
    stop("`n` must be a single number of at least 10.", call. = FALSE)
  }
  n <- as.integer(n)
  if (!is.null(seed) && (!is.numeric(seed) || length(seed) != 1L || is.na(seed))) {
    stop("`seed` must be NULL or a single number.", call. = FALSE)
  }

  x <- .prepare_inputs(species, age, dd0, map)
  if (isTRUE(warn)) .note_defaults(x)
  rows <- nrow(x)
  env <- .envelope_for(x$species)
  sd_dd0 <- .resolve_sd(sd_dd0, env$dd0_sd, rows, "sd_dd0")
  sd_map <- .resolve_sd(sd_map, env$map_sd, rows, "sd_map")

  # Central prediction (also runs the usual diagnostics)
  central <- ung_volume(x$species, x$age, x$dd0, x$map, model = model,
                        nat1_bias_correction = nat1_bias_correction, warn = warn)

  if (!is.null(seed)) {
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    if (had_seed) old_seed <- get(".Random.seed", envir = globalenv())
    on.exit({
      if (had_seed) assign(".Random.seed", old_seed, envir = globalenv())
      else rm(".Random.seed", envir = globalenv())
    }, add = TRUE)
    set.seed(seed)
  }

  # Independent normal draws of dd0 and map around the supplied values
  idx <- rep(seq_len(rows), each = n)
  d <- x[idx, c("species", "age", "dd0", "map"), drop = FALSE]
  d$dd0 <- pmax(x$dd0[idx] + sd_dd0[idx] * stats::rnorm(rows * n), 0)
  d$map <- pmax(x$map[idx] + sd_map[idx] * stats::rnorm(rows * n), 0)
  pred <- .predict(d, model, nat1_bias_correction = nat1_bias_correction)
  outside <- d$dd0 < env$dd0_min[idx] | d$dd0 > env$dd0_max[idx] |
    d$map < env$map_min[idx] | d$map > env$map_max[idx]
  prop_outside <- colMeans(matrix(outside, nrow = n))

  probs <- c(0.05, 0.5, 0.95)
  cols <- switch(model,
    Nat1 = c(Nat1 = "V_Nat1"),
    Nat2 = c(Nat2 = "V_Nat2"),
    both = c(Nat1 = "V_Nat1", Nat2 = "V_Nat2")
  )
  res <- lapply(names(cols), function(m) {
    col <- cols[[m]]
    q <- apply(matrix(pred[[col]], nrow = n), 2, stats::quantile,
               probs = probs, names = FALSE, na.rm = TRUE)
    data.frame(
      row = seq_len(rows), x, sd_dd0 = sd_dd0, sd_map = sd_map, model = m,
      volume = central[[col]], median = q[2, ], lower = q[1, ], upper = q[3, ],
      prop_outside = prop_outside, stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, res)
  out <- out[order(out$row, out$model), ]
  rownames(out) <- NULL
  attr(out, "defaulted") <- NULL
  attr(out, "n") <- n
  out
}

# One SD per stand: NULL -> species default; otherwise validate and recycle.
.resolve_sd <- function(sd, default, rows, name) {
  if (is.null(sd)) return(default)
  if (!is.numeric(sd) || anyNA(sd) || any(sd < 0) || !(length(sd) %in% c(1L, rows))) {
    stop("`", name, "` must be NULL, or non-negative numbers of length 1 or ",
         "the number of stands.", call. = FALSE)
  }
  rep_len(as.numeric(sd), rows)
}
