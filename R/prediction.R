#' Predict risk from exactly the fitted model
#'
#' Checks the incoming rows against the schema recorded at fit time, then
#' predicts on the response scale from the stored `rms` fit.
#'
#' The checks are the reason this is not a thin wrapper around
#' [stats::predict()]. A factor level the model never saw cannot be scored,
#' and `rms` signals that a long way from its cause, so an unseen level is
#' refused here by name. A value outside the range the model was developed on
#' can be scored, and is, but it is extrapolation and the result says so
#' rather than looking like any other row.
#'
#' easystats is not used for this. `insight::get_predicted()` returns NULL for
#' an `lrm` fit, so there is no prediction path through that ecosystem. See
#' `inst/capability-matrix.md`.
#'
#' @param model A [mm_model()].
#' @param newdata Rows to score. Required: a model carries no copy of the
#'   cohort, both because the specification asks that patient-level originals
#'   not be retained and because a stored copy is one that can drift from the
#'   data the caller actually has.
#' @param on_missing One of `"stop"` or `"na"`. Rows with a missing predictor
#'   cannot be scored by a complete-data model; `"stop"` refuses them and
#'   `"na"` returns `NA` for those rows. The default stands: [mm_validate()]
#'   selects its eligible rows first and then calls this function normally,
#'   rather than relaxing the refusal that a clinician holding an incomplete
#'   record most needs.
#'
#' @param interval Whether to return a confidence interval on the predicted
#'   probability. The interval comes from the standard error of the linear
#'   predictor at the supplied values, transformed to the probability scale,
#'   so it is an interval for the model's own estimate and not for the person.
#'   It covers how precisely these coefficients were estimated. It does not
#'   cover how much people sharing a covariate pattern differ from one
#'   another, and it does not cover the choices that produced the model: which
#'   predictors, which shape, which sample. A model short of the size its
#'   shape requires has an interval that is too narrow for the same reason its
#'   coefficients are too extreme.
#' @param level The coverage. Only read when `interval` is `TRUE`.
#'
#' @return A data frame with one row per input row: `.pred` on the probability
#'   scale, and `.extrapolated` marking rows outside the development range.
#'   With `interval = TRUE`, also `.lower` and `.upper`.
#'
#' @examples
#' cohort <- mm_synthetic_cohort(n = 300, seed = 1)
#' project <- mm_project("uds", "event", c("age", "bmi", "sex"),
#'                       cohort = cohort)
#' fit <- mm_model(project, cohort, nonlinear = "age")
#' head(mm_predict(fit, cohort[1:5, ]))
#' @export
mm_predict <- function(model, newdata, on_missing = c("stop", "na"),
                       interval = FALSE, level = 0.95) {
  if (!inherits(model, "mm_model")) {
    stop("`model` must come from mm_model().", call. = FALSE)
  }
  on_missing <- match.arg(on_missing)
  schema <- model$schema
  wanted <- names(schema$predictors)

  if (!is.data.frame(newdata)) {
    stop("`newdata` must be a data frame.", call. = FALSE)
  }
  absent <- setdiff(wanted, names(newdata))
  if (length(absent)) {
    stop("`newdata` is missing required predictor(s): ",
         paste(absent, collapse = ", "), call. = FALSE)
  }

  # Unseen factor levels are refused by name. rms would fail inside
  # predictrms() without saying which variable or which level.
  for (p in wanted) {
    spec <- schema$predictors[[p]]
    if (!identical(spec$type, "categorical")) next
    seen <- as.character(newdata[[p]])
    unseen <- setdiff(unique(stats::na.omit(seen)), spec$levels)
    if (length(unseen)) {
      stop("`", p, "` has level(s) the model never saw: ",
           paste(sort(unseen), collapse = ", "), ". Known: ",
           paste(spec$levels, collapse = ", "),
           ". A level absent from development cannot be scored.",
           call. = FALSE)
    }
    newdata[[p]] <- factor(seen, levels = spec$levels)
  }

  incomplete <- Reduce(`|`, lapply(wanted, function(p) is.na(newdata[[p]])))
  if (any(incomplete) && identical(on_missing, "stop")) {
    stop(sum(incomplete), " row(s) have a missing predictor. A complete-data ",
         "model cannot score them. Impute first, or pass ",
         "on_missing = \"na\".", call. = FALSE)
  }

  # Extrapolation is allowed and labelled, not silently equated with
  # interpolation.
  extrapolated <- rep(FALSE, nrow(newdata))
  for (p in wanted) {
    spec <- schema$predictors[[p]]
    if (!identical(spec$type, "numeric")) next
    v <- newdata[[p]]
    extrapolated <- extrapolated |
      (!is.na(v) & (v < spec$range[1] | v > spec$range[2]))
  }

  old <- options(datadist = model$datadist)
  on.exit(options(old), add = TRUE)

  pred <- rep(NA_real_, nrow(newdata))
  usable <- !incomplete
  if (any(usable)) {
    pred[usable] <- as.numeric(
      stats::predict(model$fit, newdata = newdata[usable, , drop = FALSE],
                     type = "fitted"))
  }

  out <- data.frame(.pred = pred, .extrapolated = extrapolated,
                    row.names = NULL)
  if (!isTRUE(interval)) return(out)

  if (!is.numeric(level) || length(level) != 1L || is.na(level) ||
      level <= 0 || level >= 1) {
    stop("`level` must be a single coverage strictly between 0 and 1.",
         call. = FALSE)
  }
  # A second call rather than deriving `.pred` from the linear predictor. The
  # fitted value is what every other part of this package is checked against,
  # the nomogram to 1e-16 among them, and an interval is not a reason to
  # compute it a different way.
  z <- stats::qnorm(1 - (1 - level) / 2)
  out$.lower <- NA_real_
  out$.upper <- NA_real_
  if (any(usable)) {
    lp <- stats::predict(model$fit, newdata = newdata[usable, , drop = FALSE],
                         type = "lp", se.fit = TRUE)
    out$.lower[usable] <- stats::plogis(lp$linear.predictors - z * lp$se.fit)
    out$.upper[usable] <- stats::plogis(lp$linear.predictors + z * lp$se.fit)
  }
  out
}

