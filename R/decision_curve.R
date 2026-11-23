# Decision curve analysis: net benefit across treatment thresholds.
#
# Ported from nomogram-final's R/mm_decision_curve.R. Its FORMULA arrived
# validated: it agrees with dcurves::dca() to 1.1e-16 on both the model and the
# treat-all curves at every threshold, and handles ties on the threshold the
# same way. `dcurves` is not a dependency here and is not needed to use this;
# it was the reference the arithmetic was checked against.
#
# WHAT THE PORT CHANGED, and why it is not a faithful copy. The original did
# its own outcome coercion, refusing anything that was not 0/1, logical, or a
# two-level factor. This package already has one rule for that question,
# mm_event_indicator(), which mm_model(), mm_validate() and the leakage checks
# all go through, and which warns by name when the event level was never
# declared. Carrying a second convention would mean a cohort whose outcome
# mm_model() fits one way could produce a net-benefit curve read the other way
# round, with nothing on the page saying so. So the coercion is the package's
# and the guards below are the original's.
#
# The three input defects the original documents are kept as the tests' negative
# controls, because they are the failure modes worth pinning rather than
# historical notes. All three were latent there: the function they replaced was
# defined and never called.
#
#   1. a two-level factor outcome returned net benefit 0 at EVERY threshold,
#      because `obs == 1` on a No/Yes factor is FALSE everywhere, so true and
#      false positives were both zero and the curve flatlined. A flat zero
#      curve reads as "this model has no clinical utility", which is a finding,
#      not an error message. The only hint was a warning about a non-numeric
#      argument to mean.default().
#   2. one NA among the predictions made the whole curve NA.
#   3. a threshold of 1 returned NaN, because net benefit divides by 1 - t.

#' Refuse a declared event level that nothing in the outcome carries
#'
#' [mm_event_indicator()] takes a declared `positive_class` on trust, which is
#' right for everything [mm_project()] validates: a project given a cohort
#' refuses a level the outcome does not carry at plan time, so by the time the
#' indicator is built the level is known to exist.
#'
#' The recalibration and decision-curve functions take an outcome and a
#' `positive` with no project between them, so nothing has checked it. Without
#' this, naming a level that does not exist returns an indicator of all zeros,
#' and the caller is then told their outcome has one class. That is true and it
#' is not the problem: which value was expected should be named. It cannot tell
#' a misnamed level from a sample that genuinely carries no events, so it
#' reports what the outcome does hold and says both readings are open. The same
#' mistake, an unrecognised level quietly becoming something else, was finding
#' W-3 in the calculator.
#'
#' @param values The outcome column.
#' @param positive The declared event level, or `NULL`.
#' @param caller The function to name in the message.
#' @return `TRUE`, invisibly, or an error.
#' @keywords internal
mm_check_positive <- function(values, positive, caller) {
  if (is.null(positive)) return(invisible(TRUE))
  if (length(positive) != 1L || is.na(positive)) {
    stop(caller, "(): `positive` must be one non-missing value naming the ",
         "event level.", call. = FALSE)
  }
  seen <- unique(as.character(stats::na.omit(values)))
  if (!as.character(positive) %in% seen) {
    stop(caller, "(): `positive` is \"", as.character(positive), "\", which ",
         "the outcome does not carry. It holds ",
         paste(sprintf("\"%s\"", utils::head(sort(seen), 5)), collapse = ", "),
         if (length(seen) > 5L) sprintf(" and %d more", length(seen) - 5L),
         ". Either the level is misnamed, or this sample carries no events; ",
         "nothing would be counted as an event either way, and without this ",
         "the result would read as an outcome with one class rather than ",
         "naming which value was expected.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Net benefit across treatment thresholds
#'
#' Decision curve analysis. For each threshold probability the function
#' reports the net benefit of treating by the model, of treating everybody, and
#' of treating nobody, so the three can be read against each other.
#'
#' A threshold is the probability at which a reader would opt for the action.
#' It carries the exchange rate between the two mistakes: at a threshold of
#' 0.1 a reader is saying one missed event costs about nine unnecessary
#' treatments, and the weight `t / (1 - t)` on false positives below is that
#' statement written as arithmetic.
#'
#' The curve says which strategy has the highest net benefit over the range of
#' thresholds a reader might hold. It does not say the model is calibrated,
#' and it is not a substitute for [mm_validate()]: a model can win on net
#' benefit over a narrow band of thresholds and still be systematically wrong
#' about the level, which is what a calibration intercept measures and what
#' [mm_recal_intercept()] corrects.
#'
#' **Computing a decision curve is not the same as being entitled to publish
#' one.** Net benefit is an explicit trade of a benefit against a harm, so the
#' curve means nothing until the decision-maker, the action and the two
#' outcomes being traded are named. This function supplies the arithmetic and
#' takes no view on whether that has been done.
#'
#' @param obs The observed outcome. Any column [mm_model()] accepts: 0/1,
#'   logical, or a two-level factor or character vector.
#' @param pred Predicted probabilities, for instance the `.pred` column of
#'   [mm_predict()].
#' @param thresholds Threshold probabilities, in `[0, 1)`.
#' @param positive The level that means the event, passed to the same rule
#'   [mm_model()] uses. `NULL` infers it, and warns when it has to.
#' @return A data frame with one row per threshold: `threshold`,
#'   `net_benefit_model`, `net_benefit_all`, `net_benefit_none`, and the
#'   `n`, `n_dropped` and `prevalence` the curve was computed on.
#' @examples
#' cohort <- mm_synthetic_cohort(n = 300, seed = 11)
#' project <- mm_project("dca", "event", c("age", "bmi"),
#'                       positive_class = 1, cohort = cohort)
#' fit <- suppressWarnings(mm_model(project, cohort))
#' scored <- mm_predict(fit, cohort)
#' curve <- mm_decision_curve(cohort$event, scored$.pred,
#'                            thresholds = seq(0, 0.3, by = 0.05),
#'                            positive = 1)
#' curve[, c("threshold", "net_benefit_model", "net_benefit_all")]
#' @export
mm_decision_curve <- function(obs, pred, thresholds = seq(0, 0.5, by = 0.01),
                              positive = NULL) {
  if (length(obs) != length(pred)) {
    stop("mm_decision_curve(): ", length(obs), " outcome(s) against ",
         length(pred), " prediction(s).", call. = FALSE)
  }
  if (!is.numeric(pred)) {
    stop("mm_decision_curve(): `pred` is ", class(pred)[1],
         ". Net benefit needs predicted probabilities.", call. = FALSE)
  }
  # The package's one rule for what an event is, so a curve cannot read an
  # outcome the other way round from the model that produced `pred`.
  mm_check_positive(obs, positive, "mm_decision_curve")
  y <- mm_event_indicator(obs, positive)

  if (!length(thresholds) || anyNA(thresholds) || !is.numeric(thresholds) ||
      any(thresholds < 0) || any(thresholds >= 1)) {
    stop("mm_decision_curve(): `thresholds` must be numbers in [0, 1). The ",
         "net-benefit weight is t / (1 - t), so 1 is not a threshold: it ",
         "returned NaN before this check existed.", call. = FALSE)
  }
  if (any(pred < 0 | pred > 1, na.rm = TRUE)) {
    stop("mm_decision_curve(): `pred` holds value(s) outside [0, 1]. A ",
         "linear predictor is not a probability; pass plogis() of it, or the ",
         "`.pred` column of mm_predict().", call. = FALSE)
  }

  # NAs are dropped and COUNTED, not propagated into every row of the curve.
  # One missing prediction used to make the whole curve NA.
  keep <- !is.na(y) & !is.na(pred)
  dropped <- sum(!keep)
  y <- y[keep]
  p <- pred[keep]
  n <- length(y)
  if (n < 1L || length(unique(y)) < 2L) {
    stop("mm_decision_curve(): ", n, " scorable row(s) carrying ",
         length(unique(y)), " outcome class(es). Net benefit needs both: ",
         "without events there are no true positives to weigh against the ",
         "false ones.", call. = FALSE)
  }

  w <- thresholds / (1 - thresholds)
  tp <- vapply(thresholds, function(t) sum(p >= t & y == 1L), numeric(1))
  fp <- vapply(thresholds, function(t) sum(p >= t & y == 0L), numeric(1))
  data.frame(
    threshold = thresholds,
    net_benefit_model = tp / n - (fp / n) * w,
    # Treating everybody: every event is a true positive and every non-event a
    # false positive, at every threshold.
    net_benefit_all = sum(y == 1L) / n - (sum(y == 0L) / n) * w,
    net_benefit_none = 0,
    n = n, n_dropped = dropped, prevalence = mean(y),
    row.names = NULL)
}
