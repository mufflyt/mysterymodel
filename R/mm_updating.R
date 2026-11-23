# Portable closed model-updating tests from nomogram-final.
# Requires separate validation before clinical application.

#' The closed test for model updating.
#'
#' @param lp the published model's linear predictor on the held-out rows
#' @param y 0/1 outcome on those rows
#' @param data the held-out frame, needed only for revision
#' @param formula the model formula, needed only for revision
#' @param alpha the level each step is tested at
#' @return a list carrying one row per step, the recommendation, and the
#'   estimates a reader needs to apply it
#' @export
mm_update_test <- function(lp, y, data = NULL, formula = NULL, alpha = 0.05) {
  ok <- is.finite(lp) & !is.na(y)
  if (sum(ok) < 20L) {
    stop("fewer than 20 usable held-out rows (", sum(ok),
         "): a closed test on this would report noise.", call. = FALSE)
  }
  lp <- lp[ok]; y <- y[ok]
  if (length(unique(y)) < 2L) {
    stop("the held-out outcome has one level, so no update is estimable.",
         call. = FALSE)
  }

  dev <- function(m) -2 * as.numeric(stats::logLik(m))
  m0 <- stats::glm(y ~ 0, family = stats::binomial, offset = lp)
  m1 <- stats::glm(y ~ 1, family = stats::binomial, offset = lp)
  m2 <- stats::glm(y ~ lp, family = stats::binomial)

  # Revision is only offered when the caller supplies what it needs. A test
  # that silently skips its most extensive alternative would recommend
  # recalibration every time and look decisive doing it.
  m3 <- NULL
  if (!is.null(data) && !is.null(formula)) {
    m3 <- tryCatch(stats::glm(formula, family = stats::binomial,
                              data = data[ok, , drop = FALSE]),
                   error = function(e) NULL)
  }

  lrt <- function(rich, simple) {
    if (is.null(rich) || is.null(simple)) return(c(NA_real_, NA_real_, NA_real_))
    d  <- dev(simple) - dev(rich)
    df <- abs(stats::df.residual(simple) - stats::df.residual(rich))
    if (df < 1) return(c(NA_real_, NA_real_, NA_real_))
    c(d, df, stats::pchisq(d, df, lower.tail = FALSE))
  }

  # THE GATE IS ONE TEST, AND THAT IS WHAT MAKES IT CLOSED. The first draft
  # walked down the ladder testing each rung at alpha, which is two or three
  # tests of one question: measured against 400 null replicates it rejected
  # "no update" 10.8% of the time at a nominal 5%, because 1 - 0.95^2 = 9.75%.
  # A closed procedure rejects a hypothesis only when every hypothesis that
  # implies it is also rejected, so the most extensive update is tested against
  # no update FIRST and nothing below runs unless that one test is significant.
  # The step-down then only chooses WHICH update, never whether.
  richest <- if (!is.null(m3)) m3 else m2
  gate <- lrt(richest, m0)

  steps <- rbind(
    data.frame(step = "gate", richer = if (!is.null(m3)) "model revision" else
                 "logistic recalibration", simpler = "no update",
               t(gate), stringsAsFactors = FALSE),
    data.frame(step = "3 vs 2", richer = "model revision",
               simpler = "logistic recalibration",
               t(lrt(m3, m2)), stringsAsFactors = FALSE),
    data.frame(step = "2 vs 1", richer = "logistic recalibration",
               simpler = "recalibration-in-the-large",
               t(lrt(m2, m1)), stringsAsFactors = FALSE),
    data.frame(step = "1 vs 0", richer = "recalibration-in-the-large",
               simpler = "no update",
               t(lrt(m1, m0)), stringsAsFactors = FALSE))
  names(steps)[4:6] <- c("lr_chisq", "df", "p")

  # The gate decides WHETHER; the rows below it decide WHICH. Taking the
  # smallest p anywhere in the table would be a different procedure with a
  # different error rate.
  rec <- "no update"
  if (!is.na(gate[3]) && gate[3] < alpha) {
    rec <- if (!is.na(steps$p[2]) && steps$p[2] < alpha) "model revision"
           else if (!is.na(steps$p[3]) && steps$p[3] < alpha) "logistic recalibration"
           else "recalibration-in-the-large"
  }

  list(steps = steps, recommended = rec, alpha = alpha, n = length(y),
       gate_p = unname(gate[3]),
       revision_tested = !is.null(m3),
       intercept_only = unname(stats::coef(m1)[1]),
       intercept = unname(stats::coef(m2)[1]),
       slope = unname(stats::coef(m2)[2]))
}

#' The closed test as one table, for an artefact.
#' @export
mm_update_table <- function(u) {
  cbind(u$steps,
        data.frame(recommended = u$recommended, alpha = u$alpha, n = u$n,
                   revision_tested = u$revision_tested,
                   gate_p = u$gate_p,
                   a_in_the_large = u$intercept_only,
                   a_logistic = u$intercept, b_logistic = u$slope,
                   stringsAsFactors = FALSE))
}
