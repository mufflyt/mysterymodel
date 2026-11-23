# Portable recalibration estimators from nomogram-final.
# No ENT-specific entry point is included.

#' Logit of a probability, clamped so 0 and 1 do not become infinite.
#'
#' THE INVERSE IS `stats::plogis()`, and it is not wrapped here. A named
#' `mm_expit()` would be a one-line alias for a base function, and the round
#' trip is already exact to within the clamp: `plogis(mm_logit(p))` returns `p`
#' for every p in [1e-10, 1 - 1e-10], and returns the clamp bound outside it.
#' That asymmetry is the point of the clamp and is the one thing a caller
#' reversing the transformation has to know, so it is stated here rather than
#' left to be discovered: a probability of exactly 0 does not survive the round
#' trip, and nothing in this pipeline feeds it one.
#'
#' The pair is used in both directions throughout: `mm_calibration()` takes the
#' logit of predicted probabilities to fit a slope, and `mm_recal_apply()` ->
#' `plogis()` takes the corrected linear predictor back to a probability.
#' `tests/test_model_contract.R` pins the round trip.
#'
#' @param p probabilities, or anything `as.numeric()` accepts
#' @return the log odds, one per element of `p`
mm_logit <- function(p) {
  p <- pmin(pmax(as.numeric(p), 1e-10), 1 - 1e-10)
  log(p / (1 - p))
}

#' Fit an intercept correction on a recalibration sample.
#'
#' `y ~ offset(lp)`, so the model's linear predictor is held fixed and the only
#' free parameter is the constant. Positive means the model predicts too low.
#'
#' The standard error is cluster-robust over `cluster` when one is supplied.
#' Applicants contribute more than one applicant-year, and the model-based SE
#' treats those rows as independent, which is too small. mm_cluster_id() in
#' R/mm_validation.R builds the identifier.
#'
#' @param lp linear predictors from the FROZEN model, not refitted here
#' @param y 0/1 outcome
#' @return list(a, se, n, events, cluster_robust, n_clusters, reason)
#' @export
mm_recal_intercept <- function(lp, y, cluster = NULL) {
  keep <- !is.na(lp) & !is.na(y)
  lp <- as.numeric(lp)[keep]; y <- as.numeric(y)[keep]
  if (!is.null(cluster)) cluster <- as.character(cluster)[keep]
  stopifnot(length(y) > 0L)
  if (length(unique(y)) < 2L)
    return(list(a = NA_real_, se = NA_real_, n = length(y), events = sum(y),
                cluster_robust = FALSE, n_clusters = NA_integer_,
                reason = sprintf(paste("recalibration sample has no outcome variation",
                                       "(%d of %d matched); no constant estimable"),
                                 sum(y), length(y))))
  m <- stats::glm(y ~ 1, family = stats::binomial(), offset = lp)
  a <- unname(stats::coef(m)[["(Intercept)"]])
  robust <- !is.null(cluster) && requireNamespace("sandwich", quietly = TRUE) &&
    length(unique(cluster)) < length(cluster)
  se <- if (robust) {
    sqrt(sandwich::vcovCL(m, cluster = cluster)[1, 1])
  } else sqrt(stats::vcov(m)[1, 1])
  list(a = a, se = se, n = length(y), events = sum(y),
       cluster_robust = robust,
       n_clusters = if (is.null(cluster)) NA_integer_ else length(unique(cluster)),
       reason = sprintf(paste("intercept correction %+.4f (SE %.4f, %s) from %d rows,",
                              "%d matched (%.1f%%)"),
                        a, se,
                        if (robust) sprintf("cluster-robust over %d applicants",
                                            length(unique(cluster)))
                        else "model-based, rows treated as independent",
                        length(y), sum(y), 100 * mean(y)))
}

#' Fit the two-parameter form, a + b * lp. b below 1 says the predictions are
#' too spread out as well as too high.
#'
#' Clustered the same way as mm_recal_intercept(), and for the same reason: an
#' applicant who appears in both held-out cycles contributes two correlated
#' rows, and both parameters' standard errors are too small without saying so.
#' b is the one that needs it, because whether b differs from 1 is the question
#' that decides between this form and the constant.
#'
#' @param lp linear predictors from the FROZEN model, not refitted here
#' @param y 0/1 outcome
#' @param cluster applicant identifier, from mm_cluster_id()
#' @return list(a, b, se_a, se_b, b_z, b_p, n, events, cluster_robust,
#'   n_clusters, reason)
#' @export
mm_recal_slope <- function(lp, y, cluster = NULL) {
  keep <- !is.na(lp) & !is.na(y)
  lp <- as.numeric(lp)[keep]; y <- as.numeric(y)[keep]
  if (!is.null(cluster)) cluster <- as.character(cluster)[keep]
  if (length(unique(y)) < 2L)
    return(list(a = NA_real_, b = NA_real_, se_a = NA_real_, se_b = NA_real_,
                b_z = NA_real_, b_p = NA_real_, n = length(y), events = sum(y),
                cluster_robust = FALSE, n_clusters = NA_integer_,
                reason = sprintf(paste("recalibration sample has no outcome variation",
                                       "(%d of %d matched); no correction estimable"),
                                 sum(y), length(y))))
  m  <- stats::glm(y ~ lp, family = stats::binomial())
  cf <- stats::coef(m)
  robust <- !is.null(cluster) && requireNamespace("sandwich", quietly = TRUE) &&
    length(unique(cluster)) < length(cluster)
  V <- if (robust) sandwich::vcovCL(m, cluster = cluster) else stats::vcov(m)
  se <- sqrt(diag(V))
  # Against 1, not against 0. A slope correction of 1 is no correction, so the
  # null that matters is b = 1; testing b = 0 would ask whether the model
  # discriminates at all, which is not the question.
  z <- (unname(cf[[2]]) - 1) / se[[2]]
  list(a = unname(cf[[1]]), b = unname(cf[[2]]),
       se_a = unname(se[[1]]), se_b = unname(se[[2]]),
       b_z = z, b_p = 2 * stats::pnorm(-abs(z)),
       n = length(y), events = sum(y),
       cluster_robust = robust,
       n_clusters = if (is.null(cluster)) NA_integer_ else length(unique(cluster)),
       reason = sprintf(paste("two-parameter correction a %+.4f (SE %.4f),",
                              "b %.4f (SE %.4f, %s from 1: z %.2f, p %.4f), %s,",
                              "from %d rows, %d matched (%.1f%%)"),
                        unname(cf[[1]]), se[[1]], unname(cf[[2]]), se[[2]],
                        if (2 * stats::pnorm(-abs(z)) < 0.05) "differs" else "indistinguishable",
                        z, 2 * stats::pnorm(-abs(z)),
                        if (robust) sprintf("cluster-robust over %d applicants",
                                            length(unique(cluster)))
                        else "model-based, rows treated as independent",
                        length(y), sum(y), 100 * mean(y)))
}

#' Apply a correction to linear predictors. b = 1 is the intercept-only form.
#' Returns probabilities, which is what the nomogram's bottom axis shows.
#' @export
mm_recal_apply <- function(lp, a, b = 1) {
  stopifnot(is.finite(a), is.finite(b))
  stats::plogis(a + b * as.numeric(lp))
}

#' Per-stratum constants. Kept for the analysis that rejected them, not called
#' by the driver. A stratum below `min_n` rows or with no outcome variation
#' gets NA and a reason rather than a number: a constant fitted on 14 rows is
#' noise, and printing it next to one fitted on 400 invites reading them alike.
#' @export
mm_recal_by <- function(lp, y, stratum, cluster = NULL, min_n = 50) {
  s <- as.character(stratum)
  out <- lapply(sort(unique(s[!is.na(s)])), function(g) {
    i <- which(s == g)
    if (length(i) < min_n)
      return(data.frame(stratum = g, a = NA_real_, se = NA_real_, n = length(i),
                        events = sum(y[i], na.rm = TRUE),
                        reason = sprintf("%d rows, below the %d-row floor; not estimated",
                                         length(i), min_n)))
    r <- mm_recal_intercept(lp[i], y[i], cluster = cluster[i])
    data.frame(stratum = g, a = r$a, se = r$se, n = r$n, events = r$events,
               reason = r$reason)
  })
  do.call(rbind, out)
}

# ---------------------------------------------------------------------------
# Pooling a correction across imputations.
#
# WHY THIS IS NEEDED NOW. The correction used to be estimated once, on the
# linear predictors of the complete held-out rows. Scoring the held-out cycles
# by multiple imputation produces m linear predictors per applicant instead of
# one, so there are m estimates of a (and of b) and they have to be combined.
#
# Averaging the estimates alone would be wrong in the direction that matters:
# it would report the within-imputation standard error as the whole of the
# uncertainty and hide the between-imputation variance, so the interval on the
# deployment constant would be too narrow precisely because the missing data
# were handled properly. Rubin's rules are what carry that variance.
#
# NOT a general-purpose MI pooler. It combines one scalar estimate and its
# standard error, which is what mm_recal_intercept() and mm_recal_slope()
# return. Anything with a covariance between parameters needs mice::pool().
# ---------------------------------------------------------------------------

#' Combine one scalar estimate across imputations by Rubin's rules.
#'
#' @param est per-imputation point estimates
#' @param se  per-imputation standard errors, same length
#' @return list(est, se, m, within, between, fmi, df, reason). Imputations
#'   whose estimate or standard error is not finite are dropped and counted,
#'   because a single imputation that failed to converge must not silently
#'   become a missing contribution to the between-imputation variance.
#' @export
mm_rubin <- function(est, se) {
  est <- as.numeric(est); se <- as.numeric(se)
  if (length(est) != length(se)) {
    stop("mm_rubin(): ", length(est), " estimates and ", length(se),
         " standard errors.", call. = FALSE)
  }
  m_in <- length(est)
  keep <- is.finite(est) & is.finite(se)
  est  <- est[keep]; se <- se[keep]
  m    <- length(est)
  if (!m) {
    return(list(est = NA_real_, se = NA_real_, m = 0L, m_dropped = m_in,
                within = NA_real_, between = NA_real_, fmi = NA_real_,
                df = NA_real_,
                reason = sprintf("no imputation produced a finite estimate (%d attempted)",
                                 m_in)))
  }
  qbar    <- mean(est)
  within  <- mean(se^2)
  # var() is NA on a single value, and a single imputation genuinely has no
  # between-imputation variance to measure, which is a different thing from an
  # unknown one. Reported as 0 with m = 1 on the record beside it.
  between <- if (m > 1L) stats::var(est) else 0
  total   <- within + (1 + 1 / m) * between
  lambda  <- if (total > 0) ((1 + 1 / m) * between) / total else 0
  list(est = qbar, se = sqrt(total), m = m, m_dropped = m_in - m,
       within = within, between = between, fmi = lambda,
       df = if (lambda > 0) (m - 1) / lambda^2 else Inf,
       reason = sprintf(paste("%+.4f (SE %.4f) pooled over %d imputation(s) by",
                              "Rubin's rules; within %.5f, between %.5f, FMI %.3f%s"),
                        qbar, sqrt(total), m, within, between, lambda,
                        if (m_in - m) sprintf(", %d dropped as non-finite", m_in - m) else ""))
}

