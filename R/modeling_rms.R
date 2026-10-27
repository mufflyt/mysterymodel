#' Fit the declared model with rms
#'
#' Builds the formula from the project, fits it with [rms::lrm()], and keeps
#' everything a later step needs: the fit, its `datadist`, the formula it was
#' actually given, a prediction schema and a fingerprint of the coefficients.
#'
#' `x` and `y` are kept on the fit, because validation and calibration need
#' them and a fit without them fails later for reasons that do not name this
#' decision.
#'
#' Strong hierarchy is enforced rather than assumed: an interaction is refused
#' unless both of its main effects are in the project's predictors. The
#' specification requires that an interaction only be usable with its
#' constituent main effects, and a formula is the last place to find out.
#'
#' @param project A [cp_project()] configuration.
#' @param cohort The development data. When the project declares a split, only
#'   rows below `split_at` are used, and the held-out rows are returned
#'   untouched for later scoring.
#' @param nonlinear Character vector of continuous predictors to fit with
#'   restricted cubic splines.
#' @param interactions List of length-two character vectors naming
#'   prespecified interactions. Exploratory discovery is not this argument.
#' @param knots Knots for each spline term.
#'
#' @return An object of class `cp_model`.
#'
#' @examples
#' cohort <- cp_synthetic_cohort(n = 300, seed = 1)
#' project <- cp_project("uds", "event",
#'                       c("age", "bmi", "sex", "prior_uti"),
#'                       cohort = cohort)
#' fit <- cp_model(project, cohort, nonlinear = "age",
#'                 interactions = list(c("prior_uti", "sex")))
#' fit
#' @export
cp_model <- function(project, cohort, nonlinear = NULL,
                     interactions = NULL, knots = 4L) {
  if (!inherits(project, "cp_project")) {
    stop("`project` must come from cp_project().", call. = FALSE)
  }
  if (!is.data.frame(cohort)) {
    stop("`cohort` must be a data frame.", call. = FALSE)
  }
  absent <- setdiff(c(project$outcome, project$predictors), names(cohort))
  if (length(absent)) {
    stop("not columns of `cohort`: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }
  if (!is.null(nonlinear)) {
    off <- setdiff(nonlinear, project$predictors)
    if (length(off)) {
      stop("`nonlinear` names terms that are not predictors: ",
           paste(off, collapse = ", "), call. = FALSE)
    }
  }

  # Strong hierarchy, checked before a formula exists.
  pairs <- interactions %||% list()
  for (ia in pairs) {
    if (length(ia) != 2L) {
      stop("each interaction must name exactly two predictors.",
           call. = FALSE)
    }
    missing_main <- setdiff(ia, project$predictors)
    if (length(missing_main)) {
      stop("interaction ", paste(ia, collapse = ":"), " needs its main ",
           "effect(s) ", paste(missing_main, collapse = ", "),
           " among the predictors. An interaction without its main ",
           "effects is not interpretable.", call. = FALSE)
    }
  }

  parts <- cp_split(project, cohort)
  dev <- parts$dev

  y <- cp_event_indicator(dev[[project$outcome]], project$positive_class)
  if (length(unique(y)) < 2L) {
    stop("the outcome does not vary in the development rows.",
         call. = FALSE)
  }
  dev[[".cp_y"]] <- y

  term_of <- function(p) {
    if (p %in% (nonlinear %||% character(0))) {
      sprintf("rms::rcs(%s, %d)", p, as.integer(knots))
    } else p
  }
  rhs <- vapply(project$predictors, term_of, character(1))
  for (ia in pairs) {
    rhs <- c(rhs, paste(term_of(ia[1]), term_of(ia[2]), sep = ":"))
  }
  form <- stats::as.formula(
    paste(".cp_y ~", paste(rhs, collapse = " + ")))

  dd <- rms::datadist(dev[, project$predictors, drop = FALSE])
  old <- options(datadist = dd)
  on.exit(options(old), add = TRUE)

  fit <- rms::lrm(form, data = dev, x = TRUE, y = TRUE)

  structure(
    list(project    = project,
         fit        = fit,
         datadist   = dd,
         formula    = form,
         nonlinear  = nonlinear,
         interactions = pairs,
         knots      = as.integer(knots),
         n_dev      = nrow(dev),
         events_dev = sum(y),
         n_held     = nrow(parts$held),
         schema     = cp_schema(project, dev),
         fingerprint = digest::digest(
           list(coef = unname(stats::coef(fit)),
                formula = deparse(form)), algo = "sha256")),
    class = "cp_model"
  )
}

#' @export
print.cp_model <- function(x, ...) {
  cat("<cp_model: ", x$project$slug, ">\n", sep = "")
  cat("  formula    ", deparse(x$formula), "\n", sep = "")
  cat("  developed  ", x$n_dev, " rows, ", x$events_dev, " events\n",
      sep = "")
  if (x$n_held > 0L) {
    cat("  held out   ", x$n_held, " rows\n", sep = "")
  }
  cat("  parameters ", length(stats::coef(x$fit)) - 1L,
      " non-intercept\n", sep = "")
  cat("  apparent C ", sprintf("%.4f", unname(x$fit$stats["C"])), "\n",
      sep = "")
  cat("  fingerprint ", substr(x$fingerprint, 1, 16), "\n", sep = "")
  invisible(x)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Turn an outcome column into a 0/1 indicator
#'
#' @param values The outcome column.
#' @param positive_class The event level, or NULL to infer.
#' @return Integer vector of 0 and 1.
#' @keywords internal
cp_event_indicator <- function(values, positive_class = NULL) {
  if (!is.null(positive_class)) {
    return(as.integer(as.character(values) == as.character(positive_class)))
  }
  if (is.numeric(values) && all(stats::na.omit(values) %in% c(0, 1))) {
    return(as.integer(values))
  }
  lev <- sort(unique(as.character(stats::na.omit(values))))
  if (length(lev) != 2L) {
    stop("cannot infer the event level from ", length(lev),
         " distinct values. Set `positive_class` in cp_project().",
         call. = FALSE)
  }
  as.integer(as.character(values) == lev[2])
}

#' Record what a deployed prediction is allowed to receive
#'
#' @param project A [cp_project()].
#' @param dev The development rows.
#' @return A list describing each predictor.
#' @keywords internal
cp_schema <- function(project, dev) {
  cols <- lapply(project$predictors, function(p) {
    v <- dev[[p]]
    if (is.factor(v) || is.character(v)) {
      list(type = "categorical", levels = levels(factor(v)))
    } else {
      list(type = "numeric",
           range = unname(range(v, na.rm = TRUE)))
    }
  })
  names(cols) <- project$predictors
  list(outcome = project$outcome,
       positive_class = project$positive_class,
       predictors = cols)
}

#' Split a cohort the way the project declares
#'
#' One place, so that fitting, validation and held-out scoring cannot disagree
#' about which rows are development.
#'
#' @param project A [cp_project()].
#' @param cohort The cohort.
#' @return A list with `dev` and `held`.
#' @keywords internal
cp_split <- function(project, cohort) {
  if (is.null(project$split_var)) {
    return(list(dev = cohort, held = cohort[0, , drop = FALSE]))
  }
  if (!project$split_var %in% names(cohort)) {
    stop("`", project$split_var, "` is not a column of the cohort.",
         call. = FALSE)
  }
  is_dev <- cohort[[project$split_var]] < project$split_at
  if (anyNA(is_dev)) {
    stop(sum(is.na(is_dev)), " row(s) have a missing ", project$split_var,
         " and so fall on neither side of the split. A row must not be ",
         "dropped silently.", call. = FALSE)
  }
  list(dev = cohort[is_dev, , drop = FALSE],
       held = cohort[!is_dev, , drop = FALSE])
}
