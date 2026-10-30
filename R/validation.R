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
#'   made rather than assumed, and this column is where it is made.
#' * **held out**, rows the project's split reserved. Scored once.
#'
#' * **bootstrap, full process**, with `full_process = TRUE`. Refits the
#'   whole strategy inside every resample, so the optimism corrected includes
#'   the data-dependent choices the fixed-model bootstrap inherits. See
#'   [mm_full_process()] for what it does and does not re-execute.
#'
#' @param model A [mm_model()].
#' @param cohort The cohort, for held-out scoring and the split.
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

  # Apparent.
  y_dev <- mm_event_indicator(parts$dev[[project$outcome]],
                              project$positive_class)
  p_dev <- mm_predict(model, parts$dev)$.pred
  rows[[length(rows) + 1L]] <- mm_metrics(p_dev, y_dev,
                                          basis = "apparent",
                           note = "scored on the development rows")

  # Bootstrap, fixed model.
  set.seed(project$seed)
  val <- rms::validate(model$fit, B = B)
  c_corrected <- 0.5 + val["Dxy", "index.corrected"] / 2
  rows[[length(rows) + 1L]] <- data.frame(
    basis = "bootstrap, fixed model",
    n = model$n_dev, events = model$events_dev,
    c_stat = c_corrected, c_lower = NA_real_, c_upper = NA_real_,
    cal_intercept = NA_real_,
    cal_slope = unname(val["Slope", "index.corrected"]),
    brier = NA_real_, brier_scaled = NA_real_,
    note = sprintf(paste("rms::validate, B = %d. Refits the same formula;",
                         "does not re-derive knots or levels, and resamples",
                         "rows even when a cluster is declared"),
                   B),
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

  # Held out.
  if (nrow(parts$held) > 0L) {
    y_held <- mm_event_indicator(parts$held[[project$outcome]],
                                 project$positive_class)
    p_held <- mm_predict(model, parts$held)$.pred
    rows[[length(rows) + 1L]] <- mm_metrics(p_held, y_held,
                                            basis = "held out",
                             note = sprintf("%s >= %s, scored once",
                                            project$split_var,
                                            format(project$split_at)))
  }

  structure(list(metrics = do.call(rbind, rows), B = B,
                 full_process = isTRUE(full_process),
                 clustered_by = model$project$cluster_id,
                 full_process_detail = fp,
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
