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
#' Full-process validation, which re-executes the whole data-dependent
#' strategy inside every resample, is a later release. Until it exists this
#' function must not be read as providing it.
#'
#' @param model A [cp_model()].
#' @param cohort The cohort, for held-out scoring and the split.
#' @param B Bootstrap resamples for [rms::validate()].
#'
#' @return An object of class `cp_validation`: a data frame of metrics by
#'   basis, plus what produced them.
#'
#' @examples
#' cohort <- cp_synthetic_cohort(n = 300, seed = 1)
#' project <- cp_project("uds", "event", c("age", "bmi", "sex"),
#'                       cohort = cohort, split_var = "year",
#'                       split_at = 2023)
#' fit <- cp_model(project, cohort, nonlinear = "age")
#' cp_validate(fit, cohort, B = 25)
#' @export
cp_validate <- function(model, cohort, B = 200L) {
  if (!inherits(model, "cp_model")) {
    stop("`model` must come from cp_model().", call. = FALSE)
  }
  if (length(B) != 1L || !is.numeric(B) || B < 1) {
    stop("`B` must be a single positive number of resamples.",
         call. = FALSE)
  }
  B <- as.integer(B)
  project <- model$project
  parts <- cp_split(project, cohort)

  old <- options(datadist = model$datadist)
  on.exit(options(old), add = TRUE)

  rows <- list()

  # Apparent.
  y_dev <- cp_event_indicator(parts$dev[[project$outcome]],
                              project$positive_class)
  p_dev <- cp_predict(model, parts$dev)$.pred
  rows[[1L]] <- cp_metrics(p_dev, y_dev, basis = "apparent",
                           note = "scored on the development rows")

  # Bootstrap, fixed model.
  set.seed(project$seed)
  val <- rms::validate(model$fit, B = B)
  c_corrected <- 0.5 + val["Dxy", "index.corrected"] / 2
  rows[[2L]] <- data.frame(
    basis = "bootstrap, fixed model",
    n = model$n_dev, events = model$events_dev,
    c_stat = c_corrected, c_lower = NA_real_, c_upper = NA_real_,
    cal_intercept = NA_real_,
    cal_slope = unname(val["Slope", "index.corrected"]),
    brier = NA_real_, brier_scaled = NA_real_,
    note = sprintf(paste("rms::validate, B = %d. Refits the same formula;",
                         "does not repeat imputation, selection or tuning"),
                   B),
    stringsAsFactors = FALSE)

  # Held out.
  if (nrow(parts$held) > 0L) {
    y_held <- cp_event_indicator(parts$held[[project$outcome]],
                                 project$positive_class)
    p_held <- cp_predict(model, parts$held)$.pred
    rows[[3L]] <- cp_metrics(p_held, y_held, basis = "held out",
                             note = sprintf("%s >= %s, scored once",
                                            project$split_var,
                                            format(project$split_at)))
  }

  structure(list(metrics = do.call(rbind, rows), B = B,
                 full_process = FALSE,
                 fingerprint = model$fingerprint),
            class = "cp_validation")
}

#' Discrimination, calibration and accuracy for one set of predictions
#'
#' @param p Predicted probabilities.
#' @param y 0/1 outcome.
#' @param basis Label for the row.
#' @param note What produced it.
#' @return A one-row data frame.
#' @keywords internal
cp_metrics <- function(p, y, basis, note = "") {
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
print.cp_validation <- function(x, ...) {
  cat("<cp_validation>  full-process: ", x$full_process, "\n", sep = "")
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
  cat("  Bootstrap validates the fixed model only. Not a strategy.\n")
  invisible(x)
}
