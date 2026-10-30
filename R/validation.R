#' Why a corrected c-statistic is reported without an interval
#'
#' DeLong's standard error is for an apparent c-statistic computed once on one
#' sample. A corrected index is an apparent one minus an average optimism, and
#' neither [rms::validate()] nor [mm_full_process()] returns the distribution
#' of that difference, so there is nothing here to put an interval around.
#'
#' The recognised answer is a nested bootstrap: an outer loop resampling the
#' cohort, each iteration running the whole correction, and a percentile
#' interval taken over the corrected values it produces. That is `B` times the
#' work of the correction itself and is not implemented. Reporting it as
#' absent, with the reason, is what keeps the apparent row's interval from
#' being read down the column as though it applied here.
#'
#' @return One sentence.
#' @keywords internal
mm_no_corrected_interval <- function() {
  paste("No interval: DeLong describes an apparent c-statistic, not a",
        "corrected one, and an interval for the corrected index needs a",
        "nested bootstrap that is not implemented here")
}

#' The fewest resamples a bootstrap correction may be averaged over
#'
#' Four fifths of the resamples requested. Both bootstraps apply it: `rms`
#' keeps only the resamples that fitted and the full-process loop counts its
#' own failures, and an optimism averaged over the survivors of a selection
#' nobody reported is not the quantity it claims to be.
#'
#' @param B Resamples requested.
#' @return The fewest that must have fitted.
#' @keywords internal
mm_min_resamples <- function(B) ceiling(0.8 * B)

#' The Brier score of predicting one constant risk for everyone
#'
#' The denominator a scaled Brier, or skill score, is taken against. Which
#' rate goes in is the whole question, so it stays the caller's to supply: a
#' column of scaled Briers each scaled by its own sample's prevalence is a set
#' of scores against different references, and a reader compares down the
#' column.
#'
#' @param rate An event rate.
#' @return The no-information Brier.
#' @keywords internal
mm_no_information <- function(rate) rate * (1 - rate)

#' Check a resample count before anything is drawn
#'
#' One contract, read by every entry point that resamples, so a public
#' function cannot validate what a lower-level one then truncates.
#'
#' `as.integer(2.7)` is 2. A caller who asked for 2.7 resamples asked for
#' something that does not exist, and silently giving them 2 answers a
#' question they did not pose. The same reasoning covers `NA`, `NaN`, the
#' infinities, a vector, and a string that looks like a number: each is
#' refused by name rather than coerced into whatever `as.integer()` makes of
#' it. An integer-valued double such as `200.0` is accepted, because it is a
#' count written with a decimal point.
#'
#' The floor is 1 rather than something larger. One resample is computable and
#' useless, and the useful threshold is already enforced elsewhere: the
#' full-process bootstrap reports itself inadequate below four fifths of `B`,
#' and so now does the fixed-model row. An arbitrary floor here would duplicate
#' that judgement in a worse place.
#'
#' Validation happens before any seed is set or any resample drawn, so a
#' refused call leaves the random-number state exactly as it found it.
#'
#' @param B The count to check.
#'
#' @return `B` as a whole number, invisibly.
#' @keywords internal
mm_check_resamples <- function(B) {
  if (!is.numeric(B)) {
    stop("`B` must be a single whole number of resamples, and is ",
         if (!length(B)) "empty" else paste0("of class ", class(B)[1]),
         ".", call. = FALSE)
  }
  if (length(B) != 1L) {
    stop("`B` must be a single whole number of resamples, and has ",
         "length ", length(B), ".", call. = FALSE)
  }
  if (is.na(B)) {
    stop("`B` is ", if (is.nan(B)) "NaN" else "NA",
         ", which is not a number of resamples.", call. = FALSE)
  }
  if (!is.finite(B)) {
    stop("`B` is ", format(B), ". A bootstrap cannot be run an ",
         "infinite number of times.", call. = FALSE)
  }
  if (B != trunc(B)) {
    stop("`B` is ", format(B), ", which is not a whole number of ",
         "resamples. Truncating it to ", trunc(B), " would answer a question ",
         "that was not asked.", call. = FALSE)
  }
  if (B < 1) {
    stop("`B` is ", format(B), ". At least one resample is needed ",
         "to estimate optimism.", call. = FALSE)
  }
  invisible(as.integer(B))
}

#' Validate the model, on a stated basis
#'
#' Returns one row per basis, because the three numbers a clinical prediction
#' paper reports are not interchangeable and presenting one as another is the
#' commonest way a published model flatters itself.
#'
#' The bases are:
#'
#' * **apparent**, the model scored on the rows it was fitted to. Always
#'   optimistic, reported so that the optimism is visible. Its calibration is
#'   withheld rather than printed: scoring an unpenalized fit on its own rows
#'   forces the intercept to zero and the slope to one, so those two numbers
#'   describe the estimator and not the model.
#' * **bootstrap, fixed model**, from [rms::validate()]. Each resample refits
#'   the *same formula*, which corrects the optimism of estimating
#'   coefficients. It does **not** repeat imputation, selection, tuning or
#'   interaction screening, so it is not validation of a modelling strategy
#'   that includes those steps. The specification requires that distinction be
#'   made rather than assumed, and this column is where it is made. It does
#'   draw whole clusters when the project declares one, by passing `cluster`
#'   through to [rms::predab.resample()], and it reports how many resamples
#'   actually fitted, because rms keeps only those and says so only when asked.
#' * **held out**, rows the project's split reserved. Scored once.
#'
#' * **bootstrap, full process**, with `full_process = TRUE`. Refits the
#'   whole strategy inside every resample, so the optimism corrected includes
#'   the data-dependent choices the fixed-model bootstrap inherits. See
#'   [mm_full_process()] for what it does and does not re-execute.
#'
#' @section Incomplete rows:
#'
#' Every basis is judged on the rows that can be judged, and the exclusions are
#' reported rather than absorbed. [mm_evaluable()] is the one rule, the same one
#' [mm_model()] fitted under, so the sample a model is measured against is the
#' sample it was estimated on; validating against a cohort whose development
#' rows do not match the fit is an error rather than a quietly different
#' number. The bootstraps resample the fitted cohort, never the supplied frame.
#'
#' A missing predictor and a missing outcome are counted apart, with the
#' overlap separately, because they are different exclusions and because taking
#' a missing outcome for a non-event leaves the event count unchanged while
#' inflating the denominator.
#'
#' Rows are selected first and [mm_predict()] is then called at its own default
#' of `on_missing = "stop"`, so the complete-case path is explicit here and
#' prediction keeps refusing to put a number on an incomplete record.
#'
#' This is complete-case analysis. It is a computational strategy and not a
#' guarantee: the estimates assume the exclusions are uninformative, which is an
#' assumption rather than a finding, and the `note` column says so whenever any
#' row was excluded. Multiple imputation is not in this package yet.
#'
#' @param model A [mm_model()].
#' @param cohort The cohort, for held-out scoring and the split. Its
#'   development rows must be the ones the model was fitted on.
#' @param B Bootstrap resamples.
#' @param full_process Also run the full-process bootstrap. Off by default
#'   because it refits `B` times and costs accordingly.
#'
#' @section The scaled Brier column:
#'
#' Every basis is scaled against one reference, the Brier of a model
#' predicting the development cohort's prevalence for everyone, reported as
#' `brier_ref`. Scaling each basis by its own prevalence is the conventional
#' within-sample skill score, and a column of those is a set of scores against
#' different references, which is a comparison a reader will make down the
#' column and should not. Where a basis has a prevalence of its own, the
#' `note` gives the value its own reference would produce.
#'
#' @return An object of class `mm_validation`: a data frame of metrics by
#'   basis, plus what produced them.
#'
#' @examples
#' cohort <- mm_synthetic_cohort(n = 300, seed = 1)
#' project <- mm_project("uds", "event", c("age", "bmi", "sex"),
#'                       cohort = cohort, split_var = "year",
#'                       split_at = 2023)
#' fit <- mm_model(project, cohort, nonlinear = "age")
#' mm_validate(fit, cohort, B = 25)
#' @export
mm_validate <- function(model, cohort, B = 200L, full_process = FALSE) {
  if (!inherits(model, "mm_model")) {
    stop("`model` must come from mm_model().", call. = FALSE)
  }
  B <- mm_check_resamples(B)
  project <- model$project
  parts <- mm_split(project, cohort)

  old <- options(datadist = model$datadist)
  on.exit(options(old), add = TRUE)

  rows <- list()

  # One eligibility rule, the same one mm_model() fitted under, applied here
  # rather than relaxed. Rows are selected first and mm_predict() is then
  # called at its own default of on_missing = "stop": validation takes an
  # explicit complete-case path instead of asking prediction to tolerate a
  # missing predictor, because a prediction from incomplete input is the thing
  # that default exists to refuse.
  dev_eligible <- mm_evaluable(project, parts$dev, require_cluster = TRUE)
  dev_scored <- parts$dev[dev_eligible$usable, , drop = FALSE]
  mm_same_development(model, dev_scored, "every basis below")

  # Apparent.
  y_dev <- mm_event_indicator(dev_scored[[project$outcome]],
                              project$positive_class)
  p_dev <- mm_predict(model, dev_scored)$.pred
  # One reference for the whole scaled-Brier column: the Brier of a model
  # predicting the development cohort's prevalence for everyone. Each sample's
  # own prevalence would be the conventional within-sample skill score, but a
  # column of those is a set of scores against different references, and a
  # reader compares down a column.
  dev_reference <- mm_no_information(mean(y_dev))

  rows[[length(rows) + 1L]] <- mm_withhold_identity_calibration(
    mm_metrics(
      p_dev, y_dev, basis = "apparent", reference = dev_reference,
      note = paste0("scored on the development rows",
                    if (dev_eligible$n_excluded > 0L)
                      paste0(". ", mm_eligibility_note(dev_eligible)))))

  # Bootstrap, fixed model. `rms::validate()` passes `...` through to
  # `predab.resample()`, which takes a cluster and draws whole units when it
  # is given one, so resampling rows under a clustered design was this
  # package's omission rather than a limit of rms. The vector is the
  # development rows in the order they were fitted, which the identity check
  # above has just established.
  validate_args <- list(model$fit, B = B)
  if (!is.null(project$cluster_id)) {
    ids <- as.character(dev_scored[[project$cluster_id]])
    if (anyNA(ids)) {
      stop(sum(is.na(ids)), " fitted row(s) have no ", project$cluster_id,
           ". `predab.resample()` splits on the cluster and would drop them ",
           "without saying so, leaving the correction computed on fewer rows ",
           "than are reported.", call. = FALSE)
    }
    validate_args$cluster <- ids
  }
  set.seed(project$seed)
  val <- do.call(rms::validate, validate_args)
  c_corrected <- 0.5 + val["Dxy", "index.corrected"] / 2

  # `predab.resample()` keeps only the resamples that fitted, `btrain[1:j, ]`,
  # and its own report of the shortfall is behind `pr`, which defaults off.
  # So a corrected index can be an average over a self-selected subset with
  # nothing on the object to say so. rms does return the count, as the `n`
  # column, and the full-process row next door has disclosed its own count
  # since it was written.
  fitted_resamples <- if ("n" %in% colnames(val)) {
    unname(val["Dxy", "n"])
  } else NA_integer_
  enough <- is.na(fitted_resamples) ||
    fitted_resamples >= mm_min_resamples(B)
  if (!enough) {
    warning("rms fitted only ", fitted_resamples, " of ", B,
            " bootstrap resamples, so the fixed-model correction is averaged ",
            "over the ones that converged. An optimism estimated from a ",
            "self-selected subset is not the quantity it claims to be.",
            call. = FALSE)
  }

  rows[[length(rows) + 1L]] <- data.frame(
    basis = "bootstrap, fixed model",
    n = model$n_dev, events = model$events_dev,
    non_events = model$n_dev - model$events_dev,
    c_stat = c_corrected, c_lower = NA_real_, c_upper = NA_real_,
    # rms corrects the calibration intercept alongside the slope and this
    # discarded it, reporting a blank where a number was available.
    cal_intercept = if ("Intercept" %in% rownames(val)) {
      unname(val["Intercept", "index.corrected"])
    } else NA_real_,
    cal_slope = unname(val["Slope", "index.corrected"]),
    brier = NA_real_, brier_ref = NA_real_, brier_scaled = NA_real_,
    note = sprintf(paste("rms::validate, %s of %d resample(s) fitted.",
                         "Refits the same formula; does not re-derive knots",
                         "or levels. Resampled by %s%s"),
                   if (is.na(fitted_resamples)) "an unreported number" else
                     format(fitted_resamples), B,
                   if (is.null(project$cluster_id)) "row" else
                     paste0("whole ", project$cluster_id),
                   if (enough) "" else
                     paste(". INADEQUATE: fewer than four fifths of the",
                           "resamples fitted")),
    stringsAsFactors = FALSE)
  rows[[length(rows)]]$note <- paste0(rows[[length(rows)]]$note, ". ",
                                      mm_no_corrected_interval())

  # Bootstrap, whole strategy.
  fp <- NULL
  if (isTRUE(full_process)) {
    fp <- mm_full_process(model, cohort, B = B)
    rows[[length(rows) + 1L]] <- data.frame(
      basis = "bootstrap, full process",
      n = model$n_dev, events = model$events_dev,
      non_events = model$n_dev - model$events_dev,
      c_stat = unname(fp$corrected[["c_stat"]]),
      c_lower = NA_real_, c_upper = NA_real_,
      cal_intercept = unname(fp$corrected[["cal_intercept"]]),
      cal_slope = unname(fp$corrected[["cal_slope"]]),
      brier = unname(fp$corrected[["brier"]]),
      brier_ref = fp$no_information_brier,
      brier_scaled = unname(fp$corrected[["brier_scaled"]]),
      note = paste0(fp$note, ". ", mm_no_corrected_interval()),
      stringsAsFactors = FALSE)
  }

  # Held out. The same rule again, with the exclusions attributed, because an
  # external cohort is where a missing outcome and a missing predictor are
  # most likely to be confused for each other.
  held_eligible <- NULL
  if (nrow(parts$held) > 0L) {
    held_eligible <- mm_evaluable(project, parts$held)
    held_scored <- parts$held[held_eligible$usable, , drop = FALSE]
    y_held <- mm_event_indicator(held_scored[[project$outcome]],
                                 project$positive_class)
    p_held <- mm_predict(model, held_scored)$.pred
    note <- sprintf("%s >= %s, scored once", project$split_var,
                    format(project$split_at))
    if (held_eligible$n_excluded > 0L) {
      note <- paste0(note, ". ", mm_eligibility_note(held_eligible))
    }
    if (held_eligible$n_scored == 0L) {
      warning("none of the ", held_eligible$n_total, " held-out row(s) can ",
              "be scored: ", held_eligible$missing_predictor,
              " lack a predictor, ", held_eligible$missing_outcome,
              " lack the outcome, ", held_eligible$missing_both,
              " lack both. The held-out row is reported with no estimate ",
              "rather than omitted, so the absence is visible.",
              call. = FALSE)
    }
    rows[[length(rows) + 1L]] <- mm_metrics(p_held, y_held,
                                            basis = "held out", note = note,
                                            reference = dev_reference)
  }

  structure(list(metrics = do.call(rbind, rows), B = B,
                 fixed_model = list(B = B, fitted = fitted_resamples,
                                    adequate = enough,
                                    clustered_by = project$cluster_id),
                 full_process = isTRUE(full_process),
                 clustered_by = model$project$cluster_id,
                 full_process_detail = fp,
                 eligibility = lapply(
                   list(development = dev_eligible, held_out = held_eligible),
                   function(e) if (is.null(e)) NULL else
                     e[setdiff(names(e), "usable")]),
                 fingerprint = model$fingerprint),
            class = "mm_validation")
}

#' Withhold a calibration that is an identity rather than an estimate
#'
#' Scoring an unpenalized maximum-likelihood fit on the very rows that produced
#' it forces the calibration intercept to zero and the slope to one: they are
#' the fit's own score equations rearranged, not evidence about calibration.
#' Printed in a column beside a held-out slope they read as the model being
#' perfectly calibrated, which is the one thing they cannot show.
#'
#' The identity is detected rather than assumed, so a fitting method that does
#' not force it, a penalized fit for instance, has its apparent calibration
#' reported as the estimate it would then be.
#'
#' @param row A one-row metrics frame from [mm_metrics()].
#' @param tol How close to 0 and 1 counts as the identity.
#' @return The row, with the calibration withheld and the reason appended when
#'   it is an identity.
#' @keywords internal
mm_withhold_identity_calibration <- function(row, tol = 1e-6) {
  if (is.na(row$cal_intercept) || is.na(row$cal_slope)) return(row)
  if (abs(row$cal_intercept) > tol || abs(row$cal_slope - 1) > tol) {
    return(row)
  }
  row$cal_intercept <- NA_real_
  row$cal_slope <- NA_real_
  row$note <- paste0(
    row$note, ". Calibration is withheld here rather than reported as 0 and ",
    "1: scoring the fit on its own rows forces both, so they describe the ",
    "estimator and not the model. The bootstrap and held-out rows carry the ",
    "calibration that can be estimated")
  row
}

#' Discrimination, calibration and accuracy for one set of predictions
#'
#' @param p Predicted probabilities. Must be numeric, the same length as `y`,
#'   and within `[0, 1]` where observed. A value outside that interval is
#'   refused rather than clamped, because clamping turns an upstream fault into
#'   a plausible score. `NA` and `NaN` are missing and are dropped pairwise,
#'   which is the package's one missing-value policy; a missing prediction is
#'   never read as a probability of zero.
#' @param y 0/1 outcome, dropped pairwise with `p` where either is missing.
#' @param basis Label for the row.
#' @param note What produced it.
#' @param reference The no-information Brier to scale against, that is the
#'   Brier of a model predicting one constant risk. `NULL` uses the scored
#'   sample's own prevalence, which is the conventional within-sample skill
#'   score and is not comparable across samples of different prevalence.
#'   [mm_validate()] passes the development cohort's reference to every basis
#'   so that one column means one thing.
#' @return A one-row data frame.
#' @keywords internal
mm_metrics <- function(p, y, basis, note = "", reference = NULL) {
  if (!is.numeric(p)) {
    stop("predicted probabilities must be numeric, and are of class ",
         class(p)[1], ".", call. = FALSE)
  }
  if (length(p) != length(y)) {
    stop("there are ", length(p), " predicted probabilit(y/ies) and ",
         length(y), " outcome(s). Recycling the shorter one would score ",
         "rows against the wrong outcomes.", call. = FALSE)
  }

  # Refused, not clamped. A probability of 1.5 was being folded to just under
  # one and turned into a plausible Brier score, which hides whatever upstream
  # produced it. NaN stays missing, under the one missing-value policy below,
  # rather than becoming a second one.
  impossible <- !is.na(p) & (!is.finite(p) | p < 0 | p > 1)
  if (any(impossible)) {
    where <- which(impossible)
    shown <- utils::head(where, 3L)
    stop("predicted probabilities must be finite and within [0, 1]. Found ",
         length(where), " invalid value(s); ",
         paste(sprintf("row %d is %s", shown, format(p[shown])),
               collapse = ", "),
         if (length(where) > length(shown))
           sprintf(" and %d more", length(where) - length(shown)),
         ".", call. = FALSE)
  }

  keep <- !is.na(p) & !is.na(y)
  p <- as.numeric(p[keep])
  y <- as.integer(y[keep])

  # Nothing to estimate from, or nothing to discriminate between. Both are
  # reported as absent with the reason attached, because pROC's error names
  # neither, and a row quietly omitted from the table reads as a basis nobody
  # asked for rather than one that could not be computed.
  if (length(y) < 1L || length(unique(y)) < 2L) {
    why <- if (length(y) < 1L) "no evaluable rows, so nothing to estimate" else
      sprintf(paste("the outcome does not vary among the %d evaluable",
                    "row(s), so discrimination is undefined"), length(y))
    return(data.frame(
      basis = basis, n = length(y), events = sum(y),
      non_events = length(y) - sum(y),
      c_stat = NA_real_, c_lower = NA_real_, c_upper = NA_real_,
      cal_intercept = NA_real_, cal_slope = NA_real_,
      brier = NA_real_, brier_ref = NA_real_, brier_scaled = NA_real_,
      note = if (nzchar(note)) paste0(note, ". ", why) else why,
      stringsAsFactors = FALSE))
  }

  # The estimate comes from the ROC and the bounds from the interval, which
  # are two computations. Reading the estimate out of the middle of
  # `ci.auc()` tied them together, and `ci.auc()` returns all `NA` when
  # DeLong cannot be computed, as with a single event, so a perfectly
  # calculable c-statistic was being discarded along with its interval.
  roc <- pROC::roc(y, p, quiet = TRUE, direction = "<")
  ci <- suppressWarnings(as.numeric(pROC::ci.auc(roc)))

  # A calibration from a fit that did not converge is not an estimate. The
  # separation that causes it is informative and the glm says so in a warning,
  # but the coefficient it leaves behind is an artefact of where iteration
  # stopped, and printed in a column it reads like a finding.
  # 0 and 1 are valid probabilities whose logits are infinite, and the
  # calibration terms are fitted on the logit scale. The nudge is confined to
  # this line: the Brier below and the c-statistic above read the probabilities
  # as given, so no reported number is computed from an altered value except
  # the two that cannot be computed otherwise.
  lp <- stats::qlogis(pmin(pmax(p, 1e-10), 1 - 1e-10))
  converged <- function(f) !is.null(f) && isTRUE(f$converged)
  fit_int <- tryCatch(
    stats::glm(y ~ 1, family = stats::binomial(), offset = lp),
    error = function(e) NULL)
  fit_slope <- tryCatch(
    stats::glm(y ~ lp, family = stats::binomial()),
    error = function(e) NULL)
  int <- if (converged(fit_int)) unname(stats::coef(fit_int)[1]) else NA_real_
  slope <- if (converged(fit_slope)) unname(stats::coef(fit_slope)[2]) else
    NA_real_

  brier <- mean((p - y)^2)
  rate <- mean(y)

  # B: the denominator a skill score is taken against. Left to itself each
  # sample uses its own prevalence, which makes a column of scaled Briers
  # a set of scores against different references.
  no_information <- if (is.null(reference)) mm_no_information(rate) else
    reference

  aside <- character(0)
  # What the interval is, and what it rests on, on every row that carries one.
  # No threshold is applied: a count of events is what governs a DeLong
  # standard error, and naming the two counts beside the method lets a reader
  # judge an interval drawn from three events without the package inventing a
  # minimum sample size it has no evidence for.
  n_events <- sum(y)
  n_non_events <- length(y) - n_events
  rests_on <- sprintf("%d event(s) and %d non-event(s)",
                      n_events, n_non_events)
  if (is.na(ci[1]) && !is.na(as.numeric(roc$auc))) {
    aside <- c(aside, sprintf(paste("the c-statistic has no interval here,",
                                    "which needs at least two of each",
                                    "outcome, and there are %s"), rests_on))
  } else if (!is.na(ci[1])) {
    aside <- c(aside, sprintf("95%% DeLong interval, from %s", rests_on))
    # Two intervals that are arithmetic rather than evidence. Both are
    # returned as rms and pROC compute them, and both are said out loud,
    # because an interval of zero width reads as precision and a limit
    # resting on the end of the parameter space reads as an estimate.
    if (isTRUE(all.equal(ci[3] - ci[1], 0))) {
      aside <- c(aside, paste("that interval has zero width, which is what",
                              "DeLong returns when the classes separate",
                              "completely or every prediction ties: the",
                              "estimator has no information left to spend",
                              "on an interval, so this is not a statement",
                              "of precision"))
    } else if (ci[1] <= 0 || ci[3] >= 1) {
      aside <- c(aside, paste("one limit sits on the edge of the parameter",
                              "space, where pROC truncates it, so that limit",
                              "is a bound and not an estimate"))
    }
  }
  withheld <- c("intercept", "slope")[c(is.na(int), is.na(slope))]
  if (length(withheld)) {
    aside <- c(aside, sprintf(paste("the calibration %s is withheld: the fit",
                                    "behind it did not converge, so its",
                                    "coefficient marks where iteration",
                                    "stopped rather than an estimate"),
                              paste(withheld, collapse = " and ")))
  }
  if (!is.null(reference) &&
      !isTRUE(all.equal(reference, mm_no_information(rate)))) {
    aside <- c(aside, sprintf(paste("the scaled Brier is taken against the",
                                    "reference %.5f, not this sample's own",
                                    "%.5f, so the column compares like with",
                                    "like; against its own it would read",
                                    "%.4f"),
                              no_information, mm_no_information(rate),
                              1 - brier / mm_no_information(rate)))
  }

  data.frame(basis = basis, n = length(y), events = sum(y),
             non_events = length(y) - sum(y),
             c_stat = as.numeric(roc$auc), c_lower = ci[1], c_upper = ci[3],
             cal_intercept = int, cal_slope = slope,
             brier = brier, brier_ref = no_information,
             brier_scaled = 1 - brier / no_information,
             note = paste(Filter(nzchar, c(note, aside)), collapse = ". "),
             stringsAsFactors = FALSE)
}

#' @export
print.mm_validation <- function(x, ...) {
  cat("<mm_validation>  full-process: ", x$full_process,
      "\n  columns: n, events/non-events, c-statistic with its 95% DeLong ",
      "interval where one is estimable\n", sep = "")
  m <- x$metrics
  for (i in seq_len(nrow(m))) {
    cat(sprintf("  %-24s n=%-5d %d/%d C=%.4f", m$basis[i], m$n[i],
                m$events[i], m$non_events[i], m$c_stat[i]))
    if (!is.na(m$c_lower[i])) {
      cat(sprintf(" (%.4f-%.4f)", m$c_lower[i], m$c_upper[i]))
      if (isTRUE(all.equal(m$c_upper[i] - m$c_lower[i], 0))) {
        cat(" zero width, see note")
      } else if (m$c_lower[i] <= 0 || m$c_upper[i] >= 1) {
        cat(" limit at a bound, see note")
      }
    } else if (!is.na(m$c_stat[i])) {
      cat(" no interval, see note")
    }
    if (!is.na(m$cal_slope[i])) {
      cat(sprintf("  slope=%.4f", m$cal_slope[i]))
    }
    cat("\n")
  }
  for (which in c("development", "held_out")) {
    e <- x$eligibility[[which]]
    if (is.null(e) || e$n_excluded == 0L) next
    cat("  ", gsub("_", " ", which), " eligibility: ", e$n_scored, " of ",
        e$n_total, " scored, ", e$missing_predictor, " missing a predictor, ",
        e$missing_outcome, " missing the outcome, ", e$missing_both,
        " both\n", sep = "")
  }
  if (!isTRUE(x$fixed_model$adequate)) {
    cat("  INADEQUATE: rms fitted ", x$fixed_model$fitted, " of ",
        x$fixed_model$B, " fixed-model resamples.\n", sep = "")
  }
  if (isTRUE(x$full_process)) {
    cat("  Full process re-derives ",
        paste(x$full_process_detail$covers, collapse = ", "),
        " per resample; ", x$full_process_detail$valid, " of ",
        x$full_process_detail$B, " valid.\n", sep = "")
    if (!isTRUE(x$full_process_detail$adequate)) {
      cat("  INADEQUATE: too few resamples fitted to trust the ",
          "correction.\n", sep = "")
    }
  } else {
    cat("  Fixed-model bootstrap only. Not validation of a strategy.\n")
  }
  invisible(x)
}
