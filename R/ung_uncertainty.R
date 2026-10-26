# Monte Carlo interval of predicted volume from climate uncertainty and the
# rounding of the published parameters. Used by ung_yield_table(uncertainty =
# TRUE); see the *Uncertainty interval* section of ?ung_yield_table.
.ung_uncertainty <- function(species, age, dd0 = NULL, map = NULL,
                            model = c("both", "Nat1", "Nat2"),
                            n = 1000, sd_dd0 = NULL, sd_map = NULL, cor = 0,
                            interval = 0.9, rounding = TRUE,
                            nat1_bias_correction = FALSE, seed = NULL,
                            warn = TRUE) {
  model <- match.arg(model)
  .check_logical(rounding, "rounding")
  .check_logical(nat1_bias_correction, "nat1_bias_correction")
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 10) {
    stop("`n` must be a single number of at least 10.", call. = FALSE)
  }
  n <- as.integer(n)
  if (!is.numeric(cor) || length(cor) != 1L || is.na(cor) || abs(cor) >= 1) {
    stop("`cor` must be a single number between -1 and 1 (exclusive).", call. = FALSE)
  }
  if (!is.numeric(interval) || length(interval) != 1L || is.na(interval) ||
      interval <= 0 || interval >= 1) {
    stop("`interval` must be a single number between 0 and 1 (exclusive).", call. = FALSE)
  }
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

  # Draws: x2 is built from z1 and an independent z2 to give correlation `cor`
  idx <- rep(seq_len(rows), each = n)
  z1 <- stats::rnorm(rows * n)
  z2 <- stats::rnorm(rows * n)
  d <- x[idx, c("species", "age", "dd0", "map"), drop = FALSE]
  d$dd0 <- pmax(x$dd0[idx] + sd_dd0[idx] * z1, 0)
  d$map <- pmax(x$map[idx] + sd_map[idx] * (cor * z1 + sqrt(1 - cor^2) * z2), 0)
  p <- NationalModelUng2009::ung_parameters
  p <- p[match(d$species, p$species), , drop = FALSE]
  if (rounding) p <- .perturb_rounding(p)
  pred <- .predict(d, model, p = p, nat1_bias_correction = nat1_bias_correction)
  outside <- d$dd0 < env$dd0_min[idx] | d$dd0 > env$dd0_max[idx] |
    d$map < env$map_min[idx] | d$map > env$map_max[idx]
  prop_outside <- colMeans(matrix(outside, nrow = n))

  probs <- c((1 - interval) / 2, 0.5, 1 - (1 - interval) / 2)
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
  attr(out, "interval") <- interval
  attr(out, "n") <- n
  out
}

# Rounding of the published parameters: each coefficient is only known to the
# precision it was printed with. Most have 4 decimal places (for example
# -139.8560). A few large values were printed with only 4 significant digits
# (for example 182, -757, -159.3); these are recognised as values of 100 or more
# with at most one decimal. Each draw gets its own value, picked at random
# within half a unit of the last printed digit. Zero means the term was dropped
# from the model, so it is left at zero. Duan factors are left alone
# (their rounding effect is negligible).
.perturb_rounding <- function(p) {
  cols <- grep("^[hgv][0-9]{2}$", names(p), value = TRUE)
  for (cc in cols) {
    v <- p[[cc]]
    short <- !is.na(v) & abs(v) >= 100 & abs(v * 10 - round(v * 10)) < 1e-8
    half <- ifelse(short, 0.5 * 10^-(3 - floor(log10(abs(v)))), 5e-5)
    half[is.na(v) | v == 0] <- 0
    p[[cc]] <- v + stats::runif(length(v), -half, half)
  }
  p
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
