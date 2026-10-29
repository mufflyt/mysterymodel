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
#' @param model A [cp_model()].
#' @param cohort The cohort.
#' @param B Resamples.
#' @param min_valid Fewest successful resamples for the result to be
#'   reported as adequate.
#'
#' @return A list with the optimism, the corrected metrics and the count of
#'   valid resamples.
#' @keywords internal
cp_full_process <- function(model, cohort, B = 200L,
                            min_valid = ceiling(0.8 * B)) {
  project <- model$project
  dev <- cp_split(project, cohort)$dev
  y_dev <- cp_event_indicator(dev[[project$outcome]],
                              project$positive_class)

  apparent <- cp_metrics(cp_predict(model, dev)$.pred, y_dev,
                         basis = "apparent")
  wanted <- c("c_stat", "cal_intercept", "cal_slope", "brier",
              "brier_scaled")

  gaps <- matrix(NA_real_, nrow = B, ncol = length(wanted),
                 dimnames = list(NULL, wanted))
  failures <- character(0)

  for (b in seq_len(B)) {
    set.seed(project$seed + b)
    ix <- cp_resample(dev, project$cluster_id)
    draw <- dev[ix, , drop = FALSE]

    outcome <- tryCatch({
      # The whole strategy, refitted: knots, datadist and level handling are
      # all re-derived from this resample rather than inherited.
      refit <- suppressWarnings(
        cp_model(project, draw, nonlinear = model$nonlinear,
                 interactions = model$interactions, knots = model$knots))
      y_draw <- cp_event_indicator(draw[[project$outcome]],
                                   project$positive_class)
      in_sample <- cp_metrics(cp_predict(refit, draw)$.pred, y_draw,
                              basis = "resample")
      out_sample <- cp_metrics(cp_predict(refit, dev)$.pred, y_dev,
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
       valid = valid, B = B, adequate = adequate, note = note,
       covers = c("knot placement", "datadist", "factor levels"),
       failures = unique(failures))
}
