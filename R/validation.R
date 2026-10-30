#' Validate the model, on a stated basis
#'
#' Returns one row per basis, because the three numbers a clinical prediction
#' paper reports are not interchangeable and presenting one as another is the
#' commonest way a published model flatters itself.
#'
#' The bases are:
#'
#' * **apparent**, the model scored on the rows it was fitted to. Always
#'   optimistic, reported so that the optimism is visible.
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
  if (length(B) != 1L || !is.numeric(B) || B < 1) {
    stop("`B` must be a single positive number of resamples.",
         call. = FALSE)
  }
  B <- as.integer(B)
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
  dev_eligible <- mm_evaluable(project, parts$dev)
  dev_scored <- parts$dev[dev_eligible$usable, , drop = FALSE]
  mm_same_development(model, dev_scored, "every basis below")

  # Apparent.
  y_dev <- mm_event_indicator(dev_scored[[project$outcome]],
                              project$positive_class)
  p_dev <- mm_predict(model, dev_scored)$.pred
  rows[[length(rows) + 1L]] <- mm_metrics(
    p_dev, y_dev, basis = "apparent",
    note = paste0("scored on the development rows",
                  if (dev_eligible$n_excluded > 0L)
                    paste0(". ", mm_eligibility_note(dev_eligible))))

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
    cal_intercept = NA_real_,
    cal_slope = unname(val["Slope", "index.corrected"]),
    brier = NA_real_, brier_scaled = NA_real_,
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
                                            basis = "held out", note = note)
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

#' Discrimination, calibration and accuracy for one set of predictions
#'
#' @param p Predicted probabilities.
#' @param y 0/1 outcome.
#' @param basis Label for the row.
#' @param note What produced it.
#' @return A one-row data frame.
#' @keywords internal
mm_metrics <- function(p, y, basis, note = "") {
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
      brier = NA_real_, brier_scaled = NA_real_,
      note = if (nzchar(note)) paste0(note, ". ", why) else why,
      stringsAsFactors = FALSE))
  }

  roc <- pROC::roc(y, p, quiet = TRUE, direction = "<")
  ci <- suppressWarnings(as.numeric(pROC::ci.auc(roc)))

  lp <- stats::qlogis(p)
  int <- tryCatch(
    unname(stats::coef(stats::glm(y ~ 1, family = stats::binomial(),
                                  offset = lp))[1]),
    error = function(e) NA_real_)
  slope <- tryCatch(
    unname(stats::coef(stats::glm(y ~ lp,
                                  family = stats::binomial()))[2]),
    error = function(e) NA_real_)

  brier <- mean((p - y)^2)
  rate <- mean(y)

  data.frame(basis = basis, n = length(y), events = sum(y),
             c_stat = ci[2], c_lower = ci[1], c_upper = ci[3],
             cal_intercept = int, cal_slope = slope,
             brier = brier,
             brier_scaled = 1 - brier / (rate * (1 - rate)),
             note = note, stringsAsFactors = FALSE)
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
