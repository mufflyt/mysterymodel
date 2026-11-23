# Multicollinearity and redundancy diagnostics.
#
# Ported from nomogram-final's R/mm_collinearity.R, where the lesson was in the
# header rather than the code: these ran ONCE by hand, found that seven
# research counts were measuring one construct between them, and the collapse
# that followed was never re-checked. Running them once is the problem, because
# the next predictor added can reintroduce exactly what the collapse removed
# and nothing would say so.
#
# Three questions, because each misses what the others catch:
#
#   VIF         how much one coefficient's variance is inflated by the other
#               predictors. Per PARAMETER, so a k-level factor contributes
#               k-1 of them, and a spline term one per basis column. Blind to
#               a variable predictable from a COMBINATION of others while
#               correlating strongly with none.
#   redundancy  can this variable be predicted from all the others? The
#               question VIF cannot ask, and the one that catches the
#               combination case.
#   pairs       the plain Spearman matrix. Neither of the above names the pair
#               a reader should look at, and a near-duplicate pair is the
#               thing a human can act on.
#
# WHAT THE PORT CHANGED. The three cutoffs were script-level constants
# (MM_VIF_MAX, MM_REDUN_R2, MM_PAIR_MAX) and are arguments here, with the same
# values as defaults. mm_collinearity_report() took a fitted object plus a
# frame and an outcome name; it takes an mm_model() and the cohort instead, and
# checks that cohort against the model's development fingerprint, because this
# package deliberately does not retain the rows it was fitted on. Diagnostics
# computed on a frame the model never saw would describe a different sample
# from the fit and read as though they described the fit.

#' Generalized variance inflation factors per variable
#'
#' Fox and Monette's generalized variance inflation factor, computed from the
#' correlation matrix of the coefficient estimates:
#' `GVIF = det(R_jj) * det(R_-j-j) / det(R)`. For a one-parameter term it
#' equals the ordinary variance inflation factor. `vif_scale` is
#' `GVIF^(1/df)`, which puts a multi-parameter term back on the scale a reader
#' compares against 4.
#'
#' @param fit An `rms` fit carrying an `assign` list.
#' @return A data frame of `variable`, `df`, `gvif`, `adjusted` and
#'   `vif_scale`, or `NULL` when the grouping is unavailable.
#' @keywords internal
mm_gvif <- function(fit) {
  V <- stats::vcov(fit)
  nm <- rownames(V)
  if (is.null(nm) || is.null(fit$assign)) return(NULL)
  drop_int <- which(nm %in% c("Intercept", "(Intercept)"))
  keep <- setdiff(seq_along(nm), drop_int)
  if (length(keep) < 2L) return(NULL)
  R <- stats::cov2cor(V[keep, keep, drop = FALSE])
  detR <- det(R)
  if (!is.finite(detR) || detR <= 0) return(NULL)
  asg <- fit$assign
  # The printed variable name, not the formula term: rms calls a spline term
  # "rms::rcs(age, 4)" and a reader is looking for "age".
  labels <- names(asg)
  if (!is.null(fit$Design$name) && length(fit$Design$name) == length(asg)) {
    labels <- fit$Design$name
  }
  rows <- lapply(seq_along(asg), function(i) {
    cols <- asg[[i]] - length(drop_int)
    cols <- cols[cols >= 1L & cols <= ncol(R)]
    if (!length(cols)) return(NULL)
    df <- length(cols)
    other <- if (length(cols) == ncol(R)) 1 else
      det(R[-cols, -cols, drop = FALSE])
    g <- det(R[cols, cols, drop = FALSE]) * other / detR
    data.frame(variable = labels[[i]], df = df, gvif = g,
               adjusted = g^(1 / (2 * df)), vif_scale = g^(1 / df),
               stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(NULL)
  out <- do.call(rbind, rows)
  out[order(-out$vif_scale), , drop = FALSE]
}

#' Variance inflation, per variable and per parameter
#'
#' THE GATE IS PER VARIABLE AND THE DETAIL IS PER PARAMETER, which is the
#' requirement `inst/capability-matrix.md` finding 3 states and the reason it
#' states it: `rms::vif()` is per model-matrix parameter, and the bases of one
#' restricted cubic spline are collinear with each other by construction. On an
#' ordinary spline model the per-parameter figures reach 126 and a check that
#' gated on them would refuse every model fitted with `nonlinear =`. The
#' per-variable figure alone reassures without detail, so both are returned and
#' both are labelled.
#'
#' @param model An [mm_model()], or the `rms::lrm` fit inside one.
#' @param max Flag a VARIABLE at or above this variance inflation factor. The
#'   default of 4 is the square of the conventional `sqrt(VIF) > 2` flag:
#'   below it a coefficient is readable.
#' @return A list with the per-variable `gvif` table, the sorted per-parameter
#'   `vif` vector, `flagged` (the per-parameter subset at or above `max`),
#'   `flagged_variables`, `ok` (decided on the per-variable figure), and a
#'   one-line `reason` naming both.
#' @examples
#' cohort <- mm_synthetic_cohort(n = 250, seed = 5)
#' fit <- suppressWarnings(mm_model(
#'   mm_project("vif", "event", c("age", "bmi"), cohort = cohort), cohort))
#' mm_vif_check(fit)$reason
#' @export
mm_vif_check <- function(model, max = 4) {
  fit <- if (inherits(model, "mm_model")) {
    mm_require_fit(model, "mm_vif_check")
    model$fit
  } else model
  if (!inherits(fit, "rms")) {
    stop("`model` must be an mm_model() or an rms fit, not ", class(fit)[1],
         ".", call. = FALSE)
  }
  if (!is.numeric(max) || length(max) != 1L || !is.finite(max) || max <= 1) {
    stop("`max` must be one number above 1. A variance inflation factor is ",
         "never below 1, so a threshold at or under it flags every ",
         "parameter.", call. = FALSE)
  }
  v <- sort(rms::vif(fit), decreasing = TRUE)
  flagged <- v[v >= max]
  g <- mm_gvif(fit)
  # The verdict rests on the per-variable figure when it is available. Without
  # the grouping there is nothing to aggregate by, and falling back to the
  # per-parameter gate is stated in the reason rather than left to be assumed.
  flagged_vars <- if (is.null(g)) character(0) else
    g$variable[g$vif_scale >= max]
  ok <- if (is.null(g)) length(flagged) == 0L else !length(flagged_vars)

  per_param <- if (!length(v)) "no parameters to check"
    else if (!length(flagged))
      sprintf("highest %.2f (%s), none at or above %g", v[1], names(v)[1], max)
    else sprintf("%d parameter(s) at or above %g: %s", length(flagged), max,
                 paste(sprintf("%s %.2f", names(flagged), flagged),
                       collapse = ", "))
  per_var <- if (is.null(g))
      "per variable: not available, so the verdict is the per-parameter one"
    else if (!length(flagged_vars))
      sprintf("per variable: highest %.2f (%s, %d df), none at or above %g",
              g$vif_scale[1], g$variable[1], g$df[1], max)
    else sprintf("per variable: %d at or above %g: %s", length(flagged_vars),
                 max, paste(sprintf("%s %.2f",
                                    g$variable[g$vif_scale >= max],
                                    g$vif_scale[g$vif_scale >= max]),
                            collapse = ", "))
  list(gvif = g, vif = v, flagged = flagged,
       flagged_variables = flagged_vars, ok = ok,
       reason = paste0("VIF: ", per_var, "; per parameter: ", per_param))
}

#' Which variables are predictable from the others
#'
#' Wraps `Hmisc::redun()`, which drops variables one at a time, so its output
#' is a SEQUENCE and not a set: the second entry is redundant given the first
#' was already dropped. Reporting it as a set would invite dropping both.
#'
#' @param data Predictors only, with the outcome already removed.
#' @param r2 The cutoff above which a variable counts as redundant.
#'   `Hmisc::redun()`'s own default, and the conventional one: a variable 90%
#'   predictable from the others carries almost nothing of its own.
#' @return A list with `r2_each`, the ordered `dropped` sequence, `ok`, and a
#'   one-line `reason`.
#' @examplesIf requireNamespace("Hmisc", quietly = TRUE)
#' cohort <- mm_synthetic_cohort(n = 250, seed = 5)
#' mm_redun_check(cohort[, c("age", "bmi")])$reason
#' @export
mm_redun_check <- function(data, r2 = 0.9) {
  if (!requireNamespace("Hmisc", quietly = TRUE)) {
    stop("mm_redun_check() needs the Hmisc package, which is a suggested ",
         "dependency rather than a required one. Install it, or use ",
         "mm_vif_check() and mm_cor_pairs(), which answer narrower ",
         "questions without it.", call. = FALSE)
  }
  if (!is.data.frame(data) || ncol(data) < 2L) {
    stop("`data` must be a data frame of two or more predictors. ",
         "Redundancy asks whether a variable is predictable from the ",
         "others, which needs others.", call. = FALSE)
  }
  # nk = 0, so linear fits only. Allowing splines lets redun() predict a
  # variable from a TRANSFORM of another and call it redundant, which is a
  # statement about the transform rather than about the variable.
  r <- Hmisc::redun(~ ., data = data, r2 = r2, nk = 0)
  each <- sort(r$rsq1, decreasing = TRUE)
  list(r2_each = each, dropped = r$Out, ok = length(r$Out) == 0L,
       reason = if (length(r$Out) == 0L)
         sprintf("redundancy: none at R2 >= %g; highest is %s at %.3f",
                 r2, names(each)[1], each[1])
       else
         sprintf(paste("redundancy: %d variable(s) predictable at R2 >= %g,",
                       "in the order redun() dropped them: %s"),
                 length(r$Out), r2, paste(r$Out, collapse = ", ")))
}

#' The strongly correlated numeric pairs, for a human to look at
#'
#' Spearman, because clinical predictors are frequently skewed and Pearson
#' would be driven by the tail. Numeric columns only: a factor's association
#' with a number is what [mm_vif_check()] and [mm_redun_check()] cover.
#'
#' @param data Predictors only.
#' @param max Report pairs at or above this absolute correlation. Worth a
#'   human looking at rather than worth failing over, which is why nothing in
#'   this file treats it as a gate.
#' @return A data frame of `a`, `b`, `rho`, sorted by `abs(rho)` descending.
#'   Possibly empty, which is the usual answer.
#' @examples
#' cohort <- mm_synthetic_cohort(n = 250, seed = 5)
#' mm_cor_pairs(cohort[, c("age", "bmi")])
#' @export
mm_cor_pairs <- function(data, max = 0.5) {
  num <- names(data)[vapply(data, is.numeric, logical(1))]
  empty <- data.frame(a = character(), b = character(), rho = numeric())
  if (length(num) < 2L) return(empty)
  m <- stats::cor(data[, num, drop = FALSE], method = "spearman",
                  use = "pairwise.complete.obs")
  m[upper.tri(m, diag = TRUE)] <- NA_real_
  ij <- which(abs(m) >= max, arr.ind = TRUE)
  if (!nrow(ij)) return(empty)
  out <- data.frame(a = rownames(m)[ij[, 1]], b = colnames(m)[ij[, 2]],
                    rho = m[ij], stringsAsFactors = FALSE)
  out[order(-abs(out$rho)), , drop = FALSE]
}

#' All three collinearity diagnostics on a fitted model
#'
#' Runs [mm_vif_check()] on the fit and [mm_redun_check()] and
#' [mm_cor_pairs()] on the development predictors, and reports them together.
#'
#' The cohort is required and is checked against the model's development
#' fingerprint, because [mm_model()] does not retain the rows it was fitted
#' on. Collinearity measured on a different frame of the same shape would
#' describe a different sample and read as though it described the fit.
#'
#' The outcome column is removed before the redundancy and correlation checks:
#' a predictor correlated with the OUTCOME is the point of the model, not a
#' problem with it.
#'
#' @param model An [mm_model()].
#' @param cohort The rows the model was developed on.
#' @param max_vif,max_r2,max_rho Passed to the three checks above.
#' @return A list with `vif`, `redun`, `pairs`, `ok` (the VIF and redundancy
#'   checks; the pair matrix is advisory and does not gate), and `text`.
#' @examplesIf requireNamespace("Hmisc", quietly = TRUE)
#' cohort <- mm_synthetic_cohort(n = 250, seed = 5)
#' fit <- suppressWarnings(mm_model(
#'   mm_project("collin", "event", c("age", "bmi"), cohort = cohort), cohort))
#' cat(mm_collinearity_report(fit, cohort)$text)
#' @export
mm_collinearity_report <- function(model, cohort, max_vif = 4, max_r2 = 0.9,
                                   max_rho = 0.5) {
  if (!inherits(model, "mm_model")) {
    stop("`model` must come from mm_model().", call. = FALSE)
  }
  mm_require_fit(model, "mm_collinearity_report")
  project <- model$project

  # The same eligibility rule mm_model() fitted under, and the same refusal
  # mm_validate() makes, rather than a second opinion about which rows count.
  parts <- mm_split(project, cohort)
  eligible <- mm_evaluable(project, parts$dev, require_cluster = TRUE)
  dev <- parts$dev[eligible$usable, , drop = FALSE]
  mm_same_development(model, dev, "these collinearity diagnostics")

  preds <- dev[, intersect(project$predictors, names(dev)), drop = FALSE]
  v <- mm_vif_check(model, max = max_vif)
  r <- if (ncol(preds) >= 2L && requireNamespace("Hmisc", quietly = TRUE)) {
    mm_redun_check(preds, r2 = max_r2)
  } else {
    list(r2_each = numeric(0), dropped = character(0), ok = TRUE,
         reason = if (ncol(preds) < 2L)
           "redundancy: one predictor, so nothing can be predicted from the others"
         else paste("redundancy: not checked, because Hmisc is not installed.",
                    "This is a gap in the report, not a clean result"))
  }
  p <- mm_cor_pairs(preds, max = max_rho)
  txt <- c(v$reason, r$reason,
           if (!nrow(p)) sprintf("pairs: no numeric pair at |rho| >= %g", max_rho)
           else sprintf("pairs at |rho| >= %g: %s", max_rho,
                        paste(sprintf("%s/%s %+.2f", p$a, p$b, p$rho),
                              collapse = ", ")))
  list(vif = v, redun = r, pairs = p, ok = v$ok && r$ok,
       text = paste(txt, collapse = "\n  "))
}

#' srr_stats: collinearity, checked three ways on every fit
#'
#' @srrstats {RE2.4} collinearity is identified by routines a caller can run on
#'   every fit rather than by hand once: mm_collinearity_report() runs three
#'   complementary diagnostics, and the header of R/collinearity.R explains why
#'   each one misses what the others catch, and why running them once by hand
#'   was the original problem.
#' @srrstats {RE2.4a} collinearity among predictors specifically is covered by
#'   all three: VIF per parameter, Hmisc::redun() for a variable predictable
#'   from a combination of the others, and the Spearman pair matrix for the
#'   near-duplicate pair a reader can act on.
#' @noRd
NULL
