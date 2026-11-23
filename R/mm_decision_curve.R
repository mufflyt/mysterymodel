# Decision curve analysis: net benefit across treatment thresholds.
#
# WHY THIS REPLACES THE INLINE VERSION. Nomogram-final.qmd carried a
# calculate_dca() that had never been checked against anything and, as it turned
# out, was never called either - 37 lines defined and invoked nowhere in the
# repository. So the defects below were LATENT: no published curve was affected.
# They would have fired the first time anyone used it.
#
# Its FORMULA is right. It agrees with dcurves::dca() to 1.1e-16 on both the
# model and treat-all curves at every threshold, and handles ties on the
# threshold the same way. Its INPUT HANDLING was not:
#
#   1. A two-level factor outcome returned net benefit 0 at EVERY threshold -
#      and that is the outcome mm_load() actually returns. `obs == 1` on a
#      No/Yes factor is FALSE everywhere, so TP and FP were both zero and the
#      curve flatlined. The only hint was a mean.default() warning about a
#      non-numeric argument. A flat zero curve reads as "this model has no
#      clinical utility", which is a finding, not an error message.
#   2. One NA among the predictions made the whole curve NA. dcurves drops them
#      and returns a number.
#   3. A threshold of 1 returned NaN, because the formula divides by 1 - t.
#
# So the formula is kept and the inputs are checked. Every refusal names itself,
# and tests/test_decision_curve.R compares the result against dcurves and uses
# all three defects above as negative controls.
#
# The analysis itself remains gated: design spec section 27 requires a signed
# declaration of the decision-maker, the action, and the benefit and harm being
# traded before a decision curve is published. This computes it; it does not
# authorise quoting it.
#
# No library() calls.

#' Net benefit across treatment thresholds.
#'
#' @param obs the observed outcome: 0/1, logical, or a two-level factor
#' @param pred predicted probabilities
#' @param thresholds treatment thresholds, in [0, 1)
#' @param positive the factor level that means the event; defaults to the second
#' @return A data frame of net benefits and complete-case counts.
#' @export
mm_decision_curve <- function(obs, pred, thresholds = seq(0, 0.5, by = 0.01),
                              positive = NULL) {
  # The outcome, coerced explicitly or refused by name. Never silently zero.
  if (is.factor(obs)) {
    lv <- levels(obs)
    if (length(lv) != 2L)
      stop("mm_decision_curve(): the outcome is a factor with ", length(lv),
           " levels (", paste(lv, collapse = ", "), "). Net benefit needs two.",
           call. = FALSE)
    pos <- positive %||% lv[2L]
    if (!pos %in% lv)
      stop("mm_decision_curve(): positive = '", pos, "' is not a level of the ",
           "outcome (", paste(lv, collapse = ", "), ").", call. = FALSE)
    y <- as.integer(obs == pos)
  } else if (is.logical(obs)) {
    y <- as.integer(obs)
  } else if (is.numeric(obs)) {
    u <- sort(unique(obs[!is.na(obs)]))
    if (!all(u %in% c(0, 1)))
      stop("mm_decision_curve(): the outcome holds ", paste(utils::head(u, 5),
           collapse = ", "), ". It must be 0/1, logical, or a two-level factor.",
           call. = FALSE)
    y <- as.integer(obs)
  } else {
    stop("mm_decision_curve(): the outcome is ", class(obs)[1],
         ". It must be 0/1, logical, or a two-level factor.", call. = FALSE)
  }

  if (!is.numeric(pred) || any(is.infinite(pred)) ||
      any(!is.na(pred) & (pred < 0 | pred > 1))) {
    stop("mm_decision_curve(): pred must contain probabilities in [0, 1].",
         call. = FALSE)
  }
  if (length(y) != length(pred))
    stop("mm_decision_curve(): ", length(y), " outcomes against ", length(pred),
         " predictions.", call. = FALSE)
  if (!is.numeric(thresholds) || !length(thresholds) ||
      any(!is.finite(thresholds)) || any(thresholds < 0) ||
      any(thresholds >= 1))
    stop("mm_decision_curve(): thresholds must be in [0, 1). The net-benefit ",
         "formula divides by 1 - t, so 1 is not a threshold; it returned NaN ",
         "before this check existed.", call. = FALSE)

  # NAs dropped and COUNTED, not propagated into every row of the curve.
  keep <- !is.na(y) & !is.na(pred)
  dropped <- sum(!keep)
  y <- y[keep]; p <- pred[keep]
  n <- length(y)
  if (n < 1L || length(unique(y)) < 2L)
    stop("mm_decision_curve(): ", n, " scorable row(s) with ",
         length(unique(y)), " outcome class(es). Net benefit needs both.",
         call. = FALSE)

  w  <- thresholds / (1 - thresholds)          # the harm-to-benefit odds
  tp <- vapply(thresholds, function(t) sum(p >= t & y == 1L), numeric(1))
  fp <- vapply(thresholds, function(t) sum(p >= t & y == 0L), numeric(1))
  data.frame(
    threshold = thresholds,
    net_benefit_model = tp / n - (fp / n) * w,
    # Treating everyone: every event is a true positive, every non-event a
    # false positive, at every threshold.
    net_benefit_all = sum(y == 1L) / n - (sum(y == 0L) / n) * w,
    net_benefit_none = 0,
    n = n, n_dropped = dropped, prevalence = mean(y),
    row.names = NULL)
}

