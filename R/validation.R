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
#' @param what The argument's name, for the message.
#'
#' @return `B` as a whole number, invisibly.
#' @keywords internal
mm_check_resamples <- function(B, what = "B") {
  if (!is.numeric(B)) {
    stop("`", what, "` must be a single whole number of resamples, and is ",
         if (!length(B)) "empty" else paste0("of class ", class(B)[1]),
         ".", call. = FALSE)
  }
  if (length(B) != 1L) {
    stop("`", what, "` must be a single whole number of resamples, and has ",
         "length ", length(B), ".", call. = FALSE)
  }
  if (is.na(B)) {
    stop("`", what, "` is ", if (is.nan(B)) "NaN" else "NA",
         ", which is not a number of resamples.", call. = FALSE)
  }
  if (!is.finite(B)) {
    stop("`", what, "` is ", format(B), ". A bootstrap cannot be run an ",
         "infinite number of times.", call. = FALSE)
  }
  if (B != trunc(B)) {
    stop("`", what, "` is ", format(B), ", which is not a whole number of ",
         "resamples. Truncating it to ", trunc(B), " would answer a question ",
         "that was not asked.", call. = FALSE)
  }
  if (B < 1) {
    stop("`", what, "` is ", format(B), ". At least one resample is needed ",
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
  dev_reference <- mean(y_dev) * (1 - mean(y_dev))

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
  enough <- is.na(fitted_resamples) || fitted_resamples >= ceiling(0.8 * B)
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
                     ". INADEQUATE: fewer than four fifths of the resamples fitted"),
    stringsAsFactors = FALSE)

  # Bootstrap, whole strategy.
  fp <- NULL
  if (isTRUE(full_process)) {
    fp <- mm_full_process(model, cohort, B = B)
    rows[[length(rows) + 1L]] <- data.frame(
      basis = "bootstrap, full process",
      n = model$n_dev, events = model$events_dev,
      c_stat = unname(fp$corrected[["c_stat"]]),
      c_lower = NA_real_, c_upper = NA_real_,
      cal_intercept = unname(fp$corrected[["cal_intercept"]]),
      cal_slope = unname(fp$corrected[["cal_slope"]]),
      brier = unname(fp$corrected[["brier"]]),
      brier_ref = fp$no_information_brier,
      brier_scaled = unname(fp$corrected[["brier_scaled"]]),
      note = fp$note, stringsAsFactors = FALSE)
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
                     e[setdiff(names(e), c("usable", "predictable"))]),
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
#' @param p Predicted probabilities.
#' @param y 0/1 outcome.
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
  keep <- !is.na(p) & !is.na(y)
  p <- pmin(pmax(as.numeric(p[keep]), 1e-10), 1 - 1e-10)
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
  lp <- stats::qlogis(p)
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
  no_information <- if (is.null(reference)) rate * (1 - rate) else reference

  aside <- character(0)
  if (is.na(ci[1]) && !is.na(as.numeric(roc$auc))) {
    aside <- c(aside, paste("the c-statistic has no interval here, which",
                            "needs at least two of each outcome"))
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
      !isTRUE(all.equal(reference, rate * (1 - rate)))) {
    aside <- c(aside, sprintf(paste("the scaled Brier is taken against the",
                                    "reference %.5f, not this sample's own",
                                    "%.5f, so the column compares like with",
                                    "like; against its own it would read",
                                    "%.4f"),
                              no_information, rate * (1 - rate),
                              1 - brier / (rate * (1 - rate))))
  }

  data.frame(basis = basis, n = length(y), events = sum(y),
             c_stat = as.numeric(roc$auc), c_lower = ci[1], c_upper = ci[3],
             cal_intercept = int, cal_slope = slope,
             brier = brier, brier_ref = no_information,
             brier_scaled = 1 - brier / no_information,
             note = paste(Filter(nzchar, c(note, aside)), collapse = ". "),
             stringsAsFactors = FALSE)
}

#' @export
print.mm_validation <- function(x, ...) {
  cat("<mm_validation>  full-process: ", x$full_process, "\n", sep = "")
  m <- x$metrics
  for (i in seq_len(nrow(m))) {
    cat(sprintf("  %-24s n=%-5d events=%-4d C=%.4f", m$basis[i], m$n[i],
                m$events[i], m$c_stat[i]))
    if (!is.na(m$c_lower[i])) {
      cat(sprintf(" (%.4f-%.4f)", m$c_lower[i], m$c_upper[i]))
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
