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
#' What it re-executes on its own is knot placement, `datadist` and factor
#' levels. Anything else the strategy learns from the data - which predictors
#' are splined, which interactions are in the model, a selection step, tuning,
#' imputation - is the caller's, and `refit` is how the caller puts it inside
#' the resampling. Without `refit` those choices are inherited from `model`
#' and the optimism excludes them, which `held_fixed` says and the note
#' repeats.
#'
#' THE CLAIM IS COMPUTED, NOT WRITTEN DOWN. `covers` and `held_fixed` are
#' built from what actually happened in this call. An earlier version stated
#' "imputation, selection and tuning are not in this pipeline yet" as a string
#' literal, which stopped being true the moment [mm_splines()] and
#' [mm_interactions()] shipped: a caller who screens, picks and then validates
#' was told the thing it most needed to doubt, and the test suite asserted the
#' sentence.
#'
#' `refit` is checked against `model` before any resample is drawn. It is
#' called once on the development rows, and the equation it produces must be
#' the equation being corrected - otherwise the optimism belongs to a model
#' nobody fitted, which is the failure that makes a wrong number look like a
#' careful one.
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
#' @param refit `NULL`, or a `function(project, draw)` returning an
#'   [mm_model()] fitted on `draw`. Supply it when the strategy makes a
#'   data-dependent choice this function cannot see - a selection step, tuning,
#'   an imputation - so the choice is re-made inside every resample and its
#'   optimism is in the correction. It is called once on the development rows
#'   first, and must give the same equation as `model`.
#'
#' @return A list with the optimism, the corrected metrics and the count of
#'   valid resamples.
#' @keywords internal
mm_full_process <- function(model, cohort, B = 200L,
                            min_valid = mm_min_resamples(B),
                            refit = NULL) {
  B <- mm_check_resamples(B)
  if (!is.null(refit) && !is.function(refit)) {
    stop("`refit` must be a function(project, draw) returning an mm_model, ",
         "not ", class(refit)[1], ".", call. = FALSE)
  }
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
  # The development cohort's own rate, which is the reference every basis in
  # mm_validate() is scaled against. The helper takes the rate as an argument
  # so that a resample's or a held-out sample's prevalence cannot arrive here
  # by being nearer to hand.
  no_information <- mm_no_information(mean(y_dev))
  apparent <- mm_metrics(mm_predict(model, dev)$.pred, y_dev,
                         basis = "apparent", reference = no_information)

  # ASSERTED, NOT ASSUMED, and before B fits are spent on it. A `refit` that
  # does something other than what produced `model` yields an optimism for a
  # different strategy, and subtracting it from this model's apparent figure
  # gives a number that is wrong in no visible way. One fit on the development
  # rows settles it; the equation is the thing compared, because that is what
  # the two have to agree about.
  if (!is.null(refit)) {
    ref <- refit(project, dev)
    if (!inherits(ref, "mm_model")) {
      stop("`refit` must return an mm_model, not ", class(ref)[1], ".",
           call. = FALSE)
    }
    one <- function(f) paste(deparse(f), collapse = " ")
    if (!identical(one(ref$formula), one(model$formula))) {
      stop("`refit` on the development rows gives a different equation from ",
           "the model being corrected, so the optimism would belong to a ",
           "model nobody fitted.\n  model: ", one(model$formula),
           "\n  refit: ", one(ref$formula), call. = FALSE)
    }
  }

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
      # `drawn`, not `refit`: the argument of that name is the caller's
      # strategy and shadowing it here would make the second resample refit
      # with the first resample's model.
      drawn <- suppressWarnings(
        if (is.null(refit))
          mm_model(project, draw, nonlinear = model$nonlinear,
                   interactions = model$interactions, knots = model$knots,
                   check_leakage = FALSE)
        else refit(project, draw))
      y_draw <- mm_event_indicator(draw[[project$outcome]],
                                   project$positive_class)
      in_sample <- mm_metrics(mm_predict(drawn, draw)$.pred, y_draw,
                              basis = "resample")
      out_sample <- mm_metrics(mm_predict(drawn, dev)$.pred, y_dev,
                               basis = "original")
      unlist(in_sample[wanted]) - unlist(out_sample[wanted])
    }, error = function(e) {
      failures <<- c(failures, conditionMessage(e))
      NULL
    })
    if (!is.null(outcome)) gaps[b, ] <- outcome
  }

  usable <- stats::complete.cases(gaps)
  valid <- sum(usable)
  optimism <- colMeans(gaps, na.rm = TRUE)
  corrected <- unlist(apparent[wanted]) - optimism

  # The correction is a mean over resamples, so it has a standard error of
  # its own, and the resamples that produced it are already in hand. Without
  # it the corrected figure is reported to as many digits as it is printed
  # with, and the seed being fixed by the project hides the variation: an
  # independent implementation of the same estimator moved the corrected
  # c-statistic by 0.0024 across seeds at this B, which is where the
  # reported precision actually stops.
  monte_carlo_se <- if (valid > 1L) {
    apply(gaps[usable, , drop = FALSE], 2, stats::sd) / sqrt(valid)
  } else stats::setNames(rep(NA_real_, length(wanted)), wanted)

  # Derived, so that apparent minus optimism still equals corrected for this
  # column and every term in it is scaled by the same constant.
  corrected[["brier_scaled"]] <- 1 - corrected[["brier"]] / no_information
  optimism[["brier_scaled"]] <- -optimism[["brier"]] / no_information
  monte_carlo_se[["brier_scaled"]] <-
    monte_carlo_se[["brier"]] / no_information

  adequate <- valid >= min_valid

  # WHAT WAS REPEATED, AND WHAT WAS NOT, read off this call rather than
  # asserted. Everything below flows from these two vectors, the note
  # included, so the claim cannot drift from the behaviour.
  covers <- c("knot placement", "datadist", "factor levels")
  held_fixed <- character(0)
  if (is.null(refit)) {
    # These are the two data-dependent choices the package itself can make -
    # mm_splines() picks the first, mm_interactions() screens the second - and
    # a resample refit that inherits them has not re-made them. Whether that
    # is correct depends on something this function cannot see: a prespecified
    # shape is right to hold fixed, one chosen by looking at these data is
    # not, and the difference lives in the analyst's head.
    if (length(model$nonlinear)) {
      held_fixed <- c(held_fixed, "which predictors are splined")
    }
    if (length(model$interactions)) {
      held_fixed <- c(held_fixed, "which interactions are in the model")
    }
  } else {
    covers <- c(covers, "the strategy `refit` re-executes")
  }

  claim <- if (length(held_fixed)) {
    paste0("HELD FIXED, so the optimism excludes it: ",
           paste(held_fixed, collapse = "; "),
           ". Correct if prespecified; if it was chosen by looking at these ",
           "rows, pass `refit` so the choice is re-made per resample")
  } else if (!is.null(refit)) {
    paste("`refit` is re-executed per resample, so whatever it chooses is",
          "inside this optimism")
  } else {
    paste("no data-dependent choice is held fixed: this model prespecifies",
          "its shape")
  }
  note <- sprintf(
    paste("full-process bootstrap, %d of %d resamples valid.",
          "Re-derives %s per resample; %s. Resampled by %s"),
    valid, B, paste(covers, collapse = ", "), claim,
    if (is.null(project$cluster_id)) "row" else
      paste0("whole ", project$cluster_id))
  if (!is.na(monte_carlo_se[["c_stat"]])) {
    note <- sprintf(
      paste("%s. The correction is a mean over resamples and carries a",
            "Monte Carlo standard error of %.5f on the c-statistic and",
            "%.5f on the slope, so these figures are determined to about",
            "%d decimal place(s) and not to as many as they print with"),
      note, monte_carlo_se[["c_stat"]], monte_carlo_se[["cal_slope"]],
      max(1L, floor(-log10(2 * monte_carlo_se[["c_stat"]]))))
  }
  if (!adequate) {
    note <- paste0(note, ". INADEQUATE: fewer than ", min_valid,
                   " resamples fitted, so the correction is averaged over ",
                   "a self-selected subset")
  }

  list(optimism = optimism, corrected = corrected, apparent = apparent,
       monte_carlo_se = monte_carlo_se,
       no_information_brier = no_information,
       eligibility = eligible[setdiff(names(eligible), "usable")],
       valid = valid, B = B, adequate = adequate, note = note,
       covers = covers, held_fixed = held_fixed,
       failures = unique(failures))
}
