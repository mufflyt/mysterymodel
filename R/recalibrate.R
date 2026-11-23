# Recalibration: correcting what a model says about the LEVEL of risk.
#
# Ported from nomogram-final's R/mm_recalibrate.R, where it existed because
# discrimination and calibration failed in different directions on the same
# model: the held-out c-statistic was 0.753 against 0.809 apparent, which is
# ordinary, while the held-out calibration intercept was +0.596, because the
# base rate had moved. A reader of a nomogram reads an absolute probability off
# the bottom axis, so a bias on the log-odds scale is the error that reaches
# them, and discrimination says nothing about it.
#
# This package already MEASURES that: mm_validate() reports a calibration
# intercept and slope. It had no way to act on them. These functions are that
# way.
#
# WHAT A CORRECTION CANNOT DO, which is the one thing to keep straight. a + b*lp
# with b > 0 is monotone, so no two patients can change places: the
# c-statistic is unchanged BY ARITHMETIC rather than by luck, and the tests
# assert exactly that. A correction moves every predicted probability toward
# the new base rate and reorders nobody. It is therefore not a remedy for a
# model that does not discriminate.
#
# b IS NOT A SHRINKAGE FACTOR, and the distinction matters enough to state.
# A slope below 1 on a held-out sample says the held-out patients are less
# spread out on this model's scale than the development ones were, which is a
# property of those two cohorts. It is not a finding that the development
# coefficients were too extreme, and it does not license shrinking them.
#
# WHAT THE PORT CHANGED. The originals took `y` as given and ran it through
# as.numeric(), so a two-level factor outcome became level codes 1 and 2 and
# glm() then refused it with a message about y values outside [0, 1] - loud,
# but about the wrong thing. They go through mm_event_indicator() here, the
# same rule mm_model() uses, so the event level cannot differ between the fit
# and its correction. Two functions were left behind: mm_logit(), because this
# package uses stats::qlogis() directly and the clamped variant had no caller
# here, and mm_recal_axis(), which is bound to the source project's held-out
# cycles, applicant clustering and artefact layout.

#' Fit an intercept correction on a recalibration sample
#'
#' Fits `y ~ offset(lp)`, so the model's linear predictor is held fixed and the
#' constant is the only free parameter. A positive value means the model
#' predicts too low.
#'
#' The standard error is cluster-robust when `cluster` is supplied and the
#' `sandwich` package is installed. When one patient contributes more than one
#' row, a model-based standard error treats those rows as independent and is
#' too small; the returned `cluster_robust` flag says which was used, rather
#' than leaving a caller to assume.
#'
#' @param lp Linear predictors from the FROZEN model, not refitted here. For an
#'   [mm_model()] these are `fitted(model, scale = "link")` on new rows.
#' @param y The observed outcome, in any form [mm_model()] accepts.
#' @param cluster An identifier for rows that are not independent, or `NULL`.
#' @param positive The level that means the event, as in [mm_project()].
#' @return A list: `a`, `se`, `n`, `events`, `cluster_robust`, `n_clusters`,
#'   and a one-line `reason`.
#' @examples
#' cohort <- mm_synthetic_cohort(n = 400, seed = 9)
#' fit <- suppressWarnings(mm_model(
#'   mm_project("recal", "event", c("age", "bmi"),
#'              positive_class = 1, cohort = cohort), cohort))
#' lp <- as.numeric(fit$fit$linear.predictors)
#' mm_recal_intercept(lp, cohort$event, positive = 1)$reason
#' @export
mm_recal_intercept <- function(lp, y, cluster = NULL, positive = NULL) {
  mm_check_positive(y, positive, "mm_recal_intercept")
  y <- mm_event_indicator(y, positive)
  lp <- as.numeric(lp)
  if (length(lp) != length(y)) {
    stop("mm_recal_intercept(): ", length(lp), " linear predictor(s) for ",
         length(y), " outcome(s).", call. = FALSE)
  }
  keep <- !is.na(lp) & !is.na(y)
  lp <- lp[keep]
  y <- y[keep]
  if (!is.null(cluster)) cluster <- as.character(cluster)[keep]
  if (!length(y)) {
    stop("mm_recal_intercept(): no row has both a linear predictor and an ",
         "outcome, so no constant is estimable.", call. = FALSE)
  }
  if (length(unique(y)) < 2L) {
    return(list(a = NA_real_, se = NA_real_, n = length(y), events = sum(y),
                cluster_robust = FALSE, n_clusters = NA_integer_,
                reason = sprintf(paste("recalibration sample has no outcome",
                                       "variation (%d event(s) in %d rows);",
                                       "no constant estimable"),
                                 sum(y), length(y))))
  }
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
       reason = sprintf(paste("intercept correction %+.4f (SE %.4f, %s) from",
                              "%d rows, %d event(s) (%.1f%%)"),
                        a, se,
                        if (robust) sprintf("cluster-robust over %d cluster(s)",
                                            length(unique(cluster)))
                        else "model-based, rows treated as independent",
                        length(y), sum(y), 100 * mean(y)))
}

#' Fit the two-parameter correction, a + b * lp
#'
#' `b` below 1 says the predictions are too spread out as well as too high.
#' Clustered the same way as [mm_recal_intercept()], and `b` is the parameter
#' that needs it, because whether `b` differs from 1 is the question that
#' decides between this form and the constant alone.
#'
#' The test on `b` is against 1, not against 0. A slope correction of 1 is no
#' correction, so the null that matters is `b = 1`; testing `b = 0` would ask
#' whether the model discriminates at all, which is a different question and
#' one [mm_validate()] already answers.
#'
#' @inheritParams mm_recal_intercept
#' @return A list: `a`, `b`, `se_a`, `se_b`, `b_z`, `b_p`, `n`, `events`,
#'   `cluster_robust`, `n_clusters`, and a one-line `reason`.
#' @examples
#' cohort <- mm_synthetic_cohort(n = 400, seed = 9)
#' fit <- suppressWarnings(mm_model(
#'   mm_project("recal", "event", c("age", "bmi"),
#'              positive_class = 1, cohort = cohort), cohort))
#' lp <- as.numeric(fit$fit$linear.predictors)
#' mm_recal_slope(lp, cohort$event, positive = 1)$b
#' @export
mm_recal_slope <- function(lp, y, cluster = NULL, positive = NULL) {
  mm_check_positive(y, positive, "mm_recal_slope")
  y <- mm_event_indicator(y, positive)
  lp <- as.numeric(lp)
  if (length(lp) != length(y)) {
    stop("mm_recal_slope(): ", length(lp), " linear predictor(s) for ",
         length(y), " outcome(s).", call. = FALSE)
  }
  keep <- !is.na(lp) & !is.na(y)
  lp <- lp[keep]
  y <- y[keep]
  if (!is.null(cluster)) cluster <- as.character(cluster)[keep]
  if (length(unique(y)) < 2L) {
    return(list(a = NA_real_, b = NA_real_, se_a = NA_real_, se_b = NA_real_,
                b_z = NA_real_, b_p = NA_real_, n = length(y),
                events = sum(y), cluster_robust = FALSE,
                n_clusters = NA_integer_,
                reason = sprintf(paste("recalibration sample has no outcome",
                                       "variation (%d event(s) in %d rows);",
                                       "no correction estimable"),
                                 sum(y), length(y))))
  }
  m <- stats::glm(y ~ lp, family = stats::binomial())
  cf <- stats::coef(m)
  robust <- !is.null(cluster) && requireNamespace("sandwich", quietly = TRUE) &&
    length(unique(cluster)) < length(cluster)
  V <- if (robust) sandwich::vcovCL(m, cluster = cluster) else stats::vcov(m)
  se <- sqrt(diag(V))
  z <- (unname(cf[[2]]) - 1) / se[[2]]
  p <- 2 * stats::pnorm(-abs(z))
  list(a = unname(cf[[1]]), b = unname(cf[[2]]),
       se_a = unname(se[[1]]), se_b = unname(se[[2]]),
       b_z = z, b_p = p, n = length(y), events = sum(y),
       cluster_robust = robust,
       n_clusters = if (is.null(cluster)) NA_integer_ else length(unique(cluster)),
       reason = sprintf(paste("two-parameter correction a %+.4f (SE %.4f),",
                              "b %.4f (SE %.4f, %s from 1: z %.2f, p %.4f),",
                              "%s, from %d rows, %d event(s) (%.1f%%)"),
                        unname(cf[[1]]), se[[1]], unname(cf[[2]]), se[[2]],
                        if (p < 0.05) "differs" else "indistinguishable",
                        z, p,
                        if (robust) sprintf("cluster-robust over %d cluster(s)",
                                            length(unique(cluster)))
                        else "model-based, rows treated as independent",
                        length(y), sum(y), 100 * mean(y)))
}

#' Apply a correction to linear predictors
#'
#' `b = 1` is the intercept-only form. Returns probabilities, which is what a
#' nomogram's bottom axis and a calculator's figure both show.
#'
#' @param lp Linear predictors from the frozen model.
#' @param a The intercept correction.
#' @param b The slope correction. 1 leaves the spread alone.
#' @return Corrected probabilities, one per element of `lp`.
#' @examples
#' mm_recal_apply(c(-1, 0, 1), a = 0.6)
#' mm_recal_apply(c(-1, 0, 1), a = 0.6, b = 0.8)
#' @export
mm_recal_apply <- function(lp, a, b = 1) {
  if (!is.numeric(a) || length(a) != 1L || !is.finite(a) ||
      !is.numeric(b) || length(b) != 1L || !is.finite(b)) {
    stop("mm_recal_apply(): `a` and `b` must each be one finite number.",
         call. = FALSE)
  }
  if (b <= 0) {
    stop("mm_recal_apply(): `b` is ", b, ". A slope at or below zero would ",
         "reverse or flatten the ranking of every patient, which is not a ",
         "recalibration: a correction is monotone or it is a different ",
         "model.", call. = FALSE)
  }
  stats::plogis(a + b * as.numeric(lp))
}

#' Per-stratum intercept corrections
#'
#' One constant per stratum, for the analysis that asks whether a single
#' correction serves every group. A stratum below `min_n` rows, or with no
#' outcome variation, returns `NA` and a reason rather than a number: a
#' constant fitted on fourteen rows is noise, and printing it beside one
#' fitted on four hundred invites reading them alike.
#'
#' In the source project this analysis REJECTED per-stratum constants: fitted
#' on one cycle they were worse than the global constant for both strata on the
#' next, and the apparent subgroup gap turned out to be a sampling artefact of
#' a single cycle. It is here so that comparison can be made, not because
#' stratifying is the expected answer.
#'
#' @inheritParams mm_recal_intercept
#' @param stratum The grouping, one value per row.
#' @param min_n The fewest rows a stratum may have and still be estimated.
#' @return A data frame with one row per stratum.
#' @examples
#' cohort <- mm_synthetic_cohort(n = 400, seed = 9)
#' fit <- suppressWarnings(mm_model(
#'   mm_project("recal", "event", c("age", "bmi"),
#'              positive_class = 1, cohort = cohort), cohort))
#' lp <- as.numeric(fit$fit$linear.predictors)
#' mm_recal_by(lp, cohort$event, cohort$sex, min_n = 50, positive = 1)
#' @export
mm_recal_by <- function(lp, y, stratum, cluster = NULL, min_n = 50,
                        positive = NULL) {
  if (length(stratum) != length(lp)) {
    stop("mm_recal_by(): ", length(stratum), " stratum value(s) for ",
         length(lp), " linear predictor(s).", call. = FALSE)
  }
  mm_check_positive(y, positive, "mm_recal_by")
  y <- mm_event_indicator(y, positive)
  s <- as.character(stratum)
  groups <- sort(unique(s[!is.na(s)]))
  if (!length(groups)) {
    stop("mm_recal_by(): every stratum value is missing.", call. = FALSE)
  }
  out <- lapply(groups, function(g) {
    i <- which(s == g)
    if (length(i) < min_n || length(unique(y[i])) < 2L) {
      return(data.frame(
        stratum = g, a = NA_real_, se = NA_real_, n = length(i),
        events = sum(y[i], na.rm = TRUE),
        reason = if (length(i) < min_n)
          sprintf("%d rows, below the %d-row floor; not estimated",
                  length(i), min_n)
        else sprintf("%d rows with %d event(s); no outcome variation",
                     length(i), sum(y[i], na.rm = TRUE)),
        stringsAsFactors = FALSE))
    }
    r <- mm_recal_intercept(lp[i], y[i], cluster = cluster[i])
    data.frame(stratum = g, a = r$a, se = r$se, n = r$n, events = r$events,
               reason = r$reason, stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}

#' Combine one scalar estimate across imputations by Rubin's rules
#'
#' Averaging the estimates alone reports the within-imputation standard error
#' as the whole of the uncertainty and hides the between-imputation variance,
#' so an interval on a deployment constant would be too narrow precisely
#' because the missing data had been handled properly. Rubin's rules carry that
#' variance.
#'
#' Not a general-purpose pooler: it combines one scalar estimate and its
#' standard error, which is what [mm_recal_intercept()] and
#' [mm_recal_slope()] return. Anything with a covariance between parameters
#' needs a full pooling implementation.
#'
#' @param est Per-imputation point estimates.
#' @param se Per-imputation standard errors, the same length.
#' @return A list: `est`, `se`, `m`, `m_dropped`, `within`, `between`, `fmi`,
#'   `df`, and a one-line `reason`. Imputations whose estimate or standard
#'   error is not finite are dropped AND counted, because one imputation that
#'   failed to converge must not silently become a missing contribution to the
#'   between-imputation variance.
#' @examples
#' mm_rubin(c(0.61, 0.58, 0.64), c(0.11, 0.12, 0.11))$reason
#' @export
mm_rubin <- function(est, se) {
  est <- as.numeric(est)
  se <- as.numeric(se)
  if (length(est) != length(se)) {
    stop("mm_rubin(): ", length(est), " estimate(s) and ", length(se),
         " standard error(s).", call. = FALSE)
  }
  m_in <- length(est)
  keep <- is.finite(est) & is.finite(se)
  est <- est[keep]
  se <- se[keep]
  m <- length(est)
  if (!m) {
    return(list(est = NA_real_, se = NA_real_, m = 0L, m_dropped = m_in,
                within = NA_real_, between = NA_real_, fmi = NA_real_,
                df = NA_real_,
                reason = sprintf(paste("no imputation produced a finite",
                                       "estimate (%d attempted)"), m_in)))
  }
  qbar <- mean(est)
  within <- mean(se^2)
  # var() is NA on a single value, and one imputation genuinely has no
  # between-imputation variance to measure, which is a different thing from an
  # unknown one. Reported as 0 with m = 1 on the record beside it.
  between <- if (m > 1L) stats::var(est) else 0
  total <- within + (1 + 1 / m) * between
  lambda <- if (total > 0) ((1 + 1 / m) * between) / total else 0
  list(est = qbar, se = sqrt(total), m = m, m_dropped = m_in - m,
       within = within, between = between, fmi = lambda,
       df = if (lambda > 0) (m - 1) / lambda^2 else Inf,
       reason = sprintf(paste("%+.4f (SE %.4f) pooled over %d imputation(s)",
                              "by Rubin's rules; within %.5f, between %.5f,",
                              "FMI %.3f%s"),
                        qbar, sqrt(total), m, within, between, lambda,
                        if (m_in - m)
                          sprintf(", %d dropped as non-finite", m_in - m)
                        else ""))
}

#' Estimate a correction on each imputation and pool it
#'
#' Scoring a sample by multiple imputation produces one linear predictor per
#' imputation per row, so there are several estimates of the correction and
#' they have to be combined. Getting the pooling wrong is invisible: the point
#' estimate is right either way and only the interval is too narrow.
#'
#' This package fits on complete rows and has no imputation of its own, so
#' `lp_mat` comes from imputing elsewhere and scoring each completed data set.
#'
#' @param lp_mat An `n` by `m` matrix of linear predictors, one column per
#'   imputation, rows in one consistent order.
#' @param y The outcome, length `n`, in that same row order.
#' @param cluster An identifier for rows that are not independent, or `NULL`.
#' @param form `"intercept"` for the constant alone, `"two-parameter"` for
#'   `a + b * lp`.
#' @param positive The level that means the event.
#' @return A list: `a`, `b`, `se_a`, `se_b`, `b_p`, `n`, `n_clusters`, `m`,
#'   `fmi_a`, `fmi_b`, `per_imputation`, and a one-line `reason`.
#' @examples
#' cohort <- mm_synthetic_cohort(n = 300, seed = 9)
#' fit <- suppressWarnings(mm_model(
#'   mm_project("recal", "event", c("age", "bmi"),
#'              positive_class = 1, cohort = cohort), cohort))
#' lp <- as.numeric(fit$fit$linear.predictors)
#' # Two "imputations" standing in for a real set, to show the shape.
#' mm_recal_mi(cbind(lp, lp + 0.05), cohort$event, positive = 1)$a
#' @export
mm_recal_mi <- function(lp_mat, y, cluster = NULL,
                        form = c("intercept", "two-parameter"),
                        positive = NULL) {
  form <- match.arg(form)
  lp_mat <- as.matrix(lp_mat)
  mm_check_positive(y, positive, "mm_recal_mi")
  y <- mm_event_indicator(y, positive)
  if (nrow(lp_mat) != length(y)) {
    stop("mm_recal_mi(): ", nrow(lp_mat), " row(s) of linear predictors for ",
         length(y), " outcome(s).", call. = FALSE)
  }
  if (!ncol(lp_mat)) {
    stop("mm_recal_mi(): `lp_mat` has no columns, so there is no imputation ",
         "to pool.", call. = FALSE)
  }
  m <- ncol(lp_mat)
  per <- lapply(seq_len(m), function(i) {
    if (identical(form, "two-parameter")) {
      mm_recal_slope(lp_mat[, i], y, cluster = cluster)
    } else mm_recal_intercept(lp_mat[, i], y, cluster = cluster)
  })

  a <- mm_rubin(vapply(per, function(r) r$a, numeric(1)),
                vapply(per, function(r) if (is.null(r$se_a)) r$se else r$se_a,
                       numeric(1)))
  b <- if (identical(form, "two-parameter")) {
    mm_rubin(vapply(per, function(r) r$b, numeric(1)),
             vapply(per, function(r) r$se_b, numeric(1)))
  } else list(est = 1, se = NA_real_, fmi = NA_real_, df = NA_real_)

  # Against 1, as mm_recal_slope() does and for the same reason, and on the
  # POOLED standard error with Rubin's degrees of freedom rather than the
  # within-imputation ones.
  b_p <- if (identical(form, "two-parameter") && is.finite(b$se) && b$se > 0) {
    2 * stats::pt(-abs((b$est - 1) / b$se), df = max(b$df, 1))
  } else NA_real_

  n <- max(vapply(per, function(r) r$n, numeric(1)))
  nc <- per[[1]]$n_clusters
  list(a = a$est, b = b$est, se_a = a$se, se_b = b$se, b_p = b_p,
       n = n, n_clusters = nc, m = a$m, fmi_a = a$fmi, fmi_b = b$fmi,
       per_imputation = per,
       reason = sprintf("%s correction, %s over %d rows, %s", form,
                        if (identical(form, "two-parameter"))
                          sprintf("a %s; b %+.4f (SE %.4f, p %.4f against 1)",
                                  a$reason, b$est, b$se, b_p)
                        else sprintf("a %s", a$reason),
                        n,
                        if (is.na(nc)) "rows treated as independent"
                        else sprintf("cluster-robust over %d cluster(s)", nc)))
}
