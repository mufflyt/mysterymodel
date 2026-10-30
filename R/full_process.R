#' Optimism of the whole modelling strategy, not just of the coefficients
#'
#' Refits the entire strategy inside every bootstrap resample and scores each
#' refit on the development rows, so the optimism being corrected includes
#' every data-dependent choice the strategy makes.
#'
#' This is the distinction the specification insists on. [rms::validate()]
#' refits one fixed formula, which corrects the optimism of estimating
#' coefficients. It does not re-derive anything the formula was chosen or
#' shaped by. Here the resample gets its own spline knot placement, its own
#' `datadist`, and its own factor-level handling, because all three are
#' learned from data and all three are part of what would be redone on a new
#' sample.
#'
#' What this does **not** yet re-execute, because the package does not do them
#' yet, is imputation, feature selection, tuning and interaction screening. A
#' strategy including any of those is not fully validated by this function
#' either, and `covers` names what was actually repeated so the claim stays
#' honest as the pipeline grows.
#'
#' Resamples that cannot be fitted are counted rather than dropped quietly. A
#' resample missing a factor level, or separating, is a real feature of small
#' cohorts, and an optimism averaged over the survivors of a selection nobody
#' reported is not the quantity it claims to be.
#'
#' @param model A [mm_model()].
#' @param cohort The cohort.
#' @param B Resamples, checked by [mm_check_resamples()] before anything is
#'   drawn.
#' @param min_valid Fewest successful resamples for the result to be
#'   reported as adequate.
#'
#' @return A list with the optimism, the corrected metrics and the count of
#'   valid resamples.
#' @keywords internal
mm_full_process <- function(model, cohort, B = 200L,
                            min_valid = ceiling(0.8 * B)) {
  B <- mm_check_resamples(B)
  project <- model$project
  # The rows the model was fitted on, not the rows it was handed. Resampling
  # the supplied frame would draw rows no refit can use, so a resample's
  # composition would depend on how much of it was missing.
  supplied <- mm_split(project, cohort)$dev
  eligible <- mm_evaluable(project, supplied, require_cluster = TRUE)
  dev <- supplied[eligible$usable, , drop = FALSE]
  mm_same_development(model, dev, "the optimism of this fit")
  y_dev <- mm_event_indicator(dev[[project$outcome]],
                              project$positive_class)


  # The scaled Brier is not differenced across resamples. It divides by
  # `rate * (1 - rate)` of whichever rows were scored, so an in-sample value
  # and an out-of-sample value are scaled by different constants and their
  # difference carries that drift as well as the optimism. The Brier itself is
  # on one scale throughout, so it is corrected and the scaled version is
  # derived from the corrected value against the development cohort's own
  # fixed denominator, which is the no-information Brier the skill score is
  # defined against.
  wanted <- c("c_stat", "cal_intercept", "cal_slope", "brier")
  rate_dev <- mean(y_dev)
  no_information <- rate_dev * (1 - rate_dev)
  apparent <- mm_metrics(mm_predict(model, dev)$.pred, y_dev,
                         basis = "apparent", reference = no_information)

  gaps <- matrix(NA_real_, nrow = B, ncol = length(wanted),
                 dimnames = list(NULL, wanted))
  failures <- character(0)

  for (b in seq_len(B)) {
    set.seed(project$seed + b)
    ix <- mm_resample(dev, project$cluster_id)
    draw <- dev[ix, , drop = FALSE]

    outcome <- tryCatch({
      # The whole strategy, refitted: knots, datadist and level handling are
      # all re-derived from this resample rather than inherited.
      refit <- suppressWarnings(
        mm_model(project, draw, nonlinear = model$nonlinear,
                 interactions = model$interactions, knots = model$knots,
                 check_leakage = FALSE))
      y_draw <- mm_event_indicator(draw[[project$outcome]],
                                   project$positive_class)
      in_sample <- mm_metrics(mm_predict(refit, draw)$.pred, y_draw,
                              basis = "resample")
      out_sample <- mm_metrics(mm_predict(refit, dev)$.pred, y_dev,
                               basis = "original")
      unlist(in_sample[wanted]) - unlist(out_sample[wanted])
    }, error = function(e) {
      failures <<- c(failures, conditionMessage(e))
      NULL
    })
    if (!is.null(outcome)) gaps[b, ] <- outcome
  }

  valid <- sum(stats::complete.cases(gaps))
  optimism <- colMeans(gaps, na.rm = TRUE)
  corrected <- unlist(apparent[wanted]) - optimism

  # Derived, so that apparent minus optimism still equals corrected for this
  # column and every term in it is scaled by the same constant.
  corrected[["brier_scaled"]] <- 1 - corrected[["brier"]] / no_information
  optimism[["brier_scaled"]] <- -optimism[["brier"]] / no_information

  adequate <- valid >= min_valid
  note <- sprintf(
    paste("full-process bootstrap, %d of %d resamples valid.",
          "Re-derives knots, datadist and factor levels per resample;",
          "%s. Resampled by %s"),
    valid, B,
    "imputation, selection and tuning are not in this pipeline yet",
    if (is.null(project$cluster_id)) "row" else
      paste0("whole ", project$cluster_id))
  if (!adequate) {
    note <- paste0(note, ". INADEQUATE: fewer than ", min_valid,
                   " resamples fitted, so the correction is averaged over ",
                   "a self-selected subset")
  }

  list(optimism = optimism, corrected = corrected, apparent = apparent,
       no_information_brier = no_information,
       eligibility = eligible[setdiff(names(eligible),
                                      c("usable", "predictable"))],
       valid = valid, B = B, adequate = adequate, note = note,
       covers = c("knot placement", "datadist", "factor levels"),
       failures = unique(failures))
}
