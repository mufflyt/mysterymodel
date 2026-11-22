#' Standard accessors for a fitted mysterymodel
#'
#' @description
#' `mm_model()` stores the fitted `rms` object at `model$fit`, and until these
#' methods existed a caller had to reach into it to get a coefficient. Each
#' method below delegates where delegation gives the right statistical
#' semantics and does the work explicitly where it does not.
#'
#' Three of them could not delegate, which is why they are written out rather
#' than aliased. Each case was established by running the generic against a
#' fitted `lrm` object, not inferred from the object's shape:
#'
#' * `stats::fitted()` on an `rms::lrm()` fit returns `NULL`, because `lrm()`
#'   does not populate `fitted.values`. A delegating method would hand back
#'   `NULL` and look like it worked.
#' * `stats::confint()` on such a fit **fails**: it dispatches to
#'   `confint.glm()`, begins profiling, and errors with `$ operator is invalid
#'   for atomic vectors`. There is therefore no profile-likelihood interval to
#'   preserve, and the Wald interval here is a documented substitute rather
#'   than a silent one.
#' * `stats::summary()` on an `rms` fit reports **effect sizes** across the
#'   predictor ranges, which is a different object from a model summary. A
#'   delegating `summary.mm_model()` would return something a reader would
#'   misread, so this one composes its own and names where the other lives.
#'
#' @param object,x A `mm_model` from [mm_model()].
#' @param ... Passed to the underlying `rms` method where one is used.
#'
#' @return As documented per method below.
#' @name mm_model-accessors
#' @seealso [mm_validate()] for performance, which these do not report.
NULL

# A fitted object is required by every accessor, and the failure has to name
# the stage rather than erroring inside rms with something unreadable.
mm_require_fit <- function(object, generic) {
  if (!inherits(object, "mm_model")) {
    stop("`object` must come from mm_model(), not ", class(object)[1], ".",
         call. = FALSE)
  }
  if (is.null(object$fit) || !inherits(object$fit, "rms")) {
    stop("this mm_model carries no fitted rms object, so ", generic,
         "() has nothing to report. mm_project() specifies a model; ",
         "mm_model() fits one.", call. = FALSE)
  }
  invisible(TRUE)
}

#' @describeIn mm_model-accessors Model coefficients, names preserved.
#' @export
coef.mm_model <- function(object, ...) {
  mm_require_fit(object, "coef")
  stats::coef(object$fit, ...)
}

#' @describeIn mm_model-accessors The coefficient variance-covariance matrix.
#' @export
vcov.mm_model <- function(object, ...) {
  mm_require_fit(object, "vcov")
  stats::vcov(object$fit, ...)
}

#' @describeIn mm_model-accessors The fitted formula. Its response term is the
#'   package's internal recoded outcome (`.mm_y`), not the column named in
#'   `mm_project(outcome = )`; `object$project$outcome` is that column.
#' @export
formula.mm_model <- function(x, ...) {
  mm_require_fit(x, "formula")
  x$formula
}

#' @describeIn mm_model-accessors The number of observations the model was
#'   fitted on, which is the development rows after complete-case exclusion,
#'   not the rows supplied. `object$n_supplied` and `object$n_held` are the
#'   other two counts, and they are different numbers on purpose.
#' @export
nobs.mm_model <- function(object, ...) {
  mm_require_fit(object, "nobs")
  object$n_dev
}

#' @describeIn mm_model-accessors Fitted values. `scale = "response"` (the
#'   default) gives predicted probabilities; `scale = "link"` gives the linear
#'   predictor. The scale is an argument rather than an assumption because
#'   `rms::lrm()` leaves `fitted.values` empty, so there is no inherited
#'   convention to follow.
#' @param scale `"response"` for probabilities, `"link"` for the linear
#'   predictor.
#' @export
fitted.mm_model <- function(object, scale = c("response", "link"), ...) {
  mm_require_fit(object, "fitted")
  scale <- match.arg(scale)
  if (scale == "link") return(object$fit$linear.predictors)
  stats::predict(object$fit, type = "fitted")
}

#' @describeIn mm_model-accessors Residuals. `type` is passed to
#'   [rms::residuals.lrm()], which supports `"ordinary"`, `"li.shepherd"`,
#'   `"score"`, `"pearson"`, `"deviance"`, `"pseudo.dep"`, `"partial"`,
#'   `"dfbeta"` and `"gof"`. The default is `"deviance"`. `"score"`,
#'   `"partial"` and `"dfbeta"` return a matrix rather than a vector, and the
#'   types are not interchangeable: a residual's interpretation follows its
#'   definition, so read `?rms::residuals.lrm` before comparing two of them.
#' @param type Residual type, passed to `rms`.
#' @export
residuals.mm_model <- function(object, type = "deviance", ...) {
  mm_require_fit(object, "residuals")
  stats::residuals(object$fit, type = type, ...)
}

#' @describeIn mm_model-accessors Wald confidence intervals on the
#'   coefficients, from [vcov()].
#'
#'   **These are Wald intervals, and that is a substitute rather than a
#'   preference.** `stats::confint()` on an `rms::lrm()` fit dispatches to
#'   `confint.glm()`, which attempts profile likelihood and errors, so no
#'   profile interval is available to return. They are intervals on the
#'   coefficient scale and are not the interval `mm_validate()` reports on the
#'   c-statistic, which is a DeLong interval on a performance measure. Reading
#'   one as the other misreports the model.
#' @param parm Coefficients to report; defaults to all.
#' @param level Coverage.
#' @export
confint.mm_model <- function(object, parm, level = 0.95, ...) {
  mm_require_fit(object, "confint")
  if (!is.numeric(level) || length(level) != 1L || is.na(level) ||
      level <= 0 || level >= 1) {
    stop("`level` must be one number strictly between 0 and 1.", call. = FALSE)
  }
  est <- stats::coef(object$fit)
  se <- sqrt(diag(stats::vcov(object$fit)))
  se <- se[names(est)]
  z <- stats::qnorm(1 - (1 - level) / 2)
  out <- cbind(est - z * se, est + z * se)
  colnames(out) <- paste(format(100 * c((1 - level) / 2, 1 - (1 - level) / 2),
                                trim = TRUE), "%")
  rownames(out) <- names(est)
  if (!missing(parm)) out <- out[parm, , drop = FALSE]
  out
}

#' @describeIn mm_model-accessors A summary of the fitted model: its call, the
#'   three row counts, the parameter budget, and the coefficients with their
#'   Wald intervals.
#'
#'   **It reports no performance.** Discrimination, calibration and bootstrap
#'   optimism come from [mm_validate()], and a fitted-model summary that
#'   printed them beside the coefficients would invite a reader to treat an
#'   apparent number as a validated one. `rms::summary()` on `object$fit` is a
#'   different object again: effect sizes across predictor ranges.
#' @export
summary.mm_model <- function(object, level = 0.95, ...) {
  mm_require_fit(object, "summary")
  ci <- confint.mm_model(object, level = level)
  se <- sqrt(diag(stats::vcov(object$fit)))[rownames(ci)]
  coefs <- data.frame(
    term = rownames(ci), estimate = stats::coef(object$fit),
    std_error = se, lower = ci[, 1], upper = ci[, 2],
    row.names = NULL, stringsAsFactors = FALSE)
  structure(
    list(formula = object$formula,
         outcome = object$project$outcome,
         n = c(supplied = object$n_supplied,
               developed = object$n_dev,
               held_out = object$n_held,
               excluded_incomplete = object$n_incomplete),
         events = object$events_dev,
         parameters = object$parameter_budget,
         coefficients = coefs,
         level = level),
    class = "summary.mm_model")
}

#' @describeIn mm_model-accessors Print method for the summary.
#' @export
print.summary.mm_model <- function(x, ...) {
  cat("<summary.mm_model>\n")
  cat("  formula    ", deparse(x$formula), "\n")
  cat("  outcome    ", x$outcome, "\n")
  cat("  rows       ",
      paste(sprintf("%s=%s", names(x$n), x$n), collapse = "  "), "\n")
  cat("  events     ", x$events, " parameters ", x$parameters, "\n")
  cat("  coefficients, with ", format(100 * x$level, trim = TRUE),
      "% Wald intervals:\n", sep = "")
  print(x$coefficients, row.names = FALSE, digits = 4)
  cat("  performance is NOT reported here; see mm_validate().\n")
  invisible(x)
}
