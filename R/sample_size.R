#' Is the development sample adequate for the parameters spent
#'
#' Reports what the specification asks a prediction model to disclose about
#' its own size: rows, events, prevalence, the number of candidate parameters
#' including spline and interaction terms, the expected shrinkage, and the
#' development sample a model of this shape would need.
#'
#' The gate is the Riley requirement from [pmsampsize::pmsampsize()], not the
#' events-per-parameter rule. Events per parameter is reported because readers
#' expect it, and labelled as description rather than as the criterion, which
#' is what the specification asks for.
#'
#' One circularity is disclosed rather than hidden. The required sample size
#' depends on the model's explanatory performance, which before fitting is a
#' guess and after fitting is an estimate from the very data whose adequacy is
#' in question. The figure here uses the fitted Nagelkerke R-squared, so it
#' answers "was this sample adequate for the model it produced", not "how
#' large a sample should have been collected". The second question needs an
#' R-squared from outside these data.
#'
#' @param n Development rows.
#' @param events Outcome events among them.
#' @param parameters Non-intercept model parameters.
#' @param nagelkerke Nagelkerke R-squared from the fitted model.
#' @param likelihood_ratio Model likelihood ratio chi-squared.
#' @param shrinkage Target shrinkage for the requirement, conventionally 0.9.
#'
#' @return An object of class `mm_adequacy`.
#' @keywords internal
mm_adequacy <- function(n, events, parameters, nagelkerke,
                        likelihood_ratio = NA_real_, shrinkage = 0.9) {
  prevalence <- events / n

  # Heuristic shrinkage, Van Houwelingen and le Cessie: the fraction of the
  # model's apparent signal that is not explained by its own degrees of
  # freedom. Below about 0.9 the coefficients are expected to be overfitted
  # by more than a tenth.
  heuristic <- if (is.na(likelihood_ratio) || likelihood_ratio <= 0) {
    NA_real_
  } else {
    (likelihood_ratio - parameters) / likelihood_ratio
  }

  required <- tryCatch({
    out <- utils::capture.output(
      res <- pmsampsize::pmsampsize(
        type = "b", nagrsquared = nagelkerke, parameters = parameters,
        shrinkage = shrinkage, prevalence = prevalence))
    list(n = res$sample_size, events = res$events, epp = res$EPP)
  }, error = function(e) list(n = NA_real_, events = NA_real_,
                              epp = NA_real_))

  short_by <- if (is.na(required$n)) NA_real_ else required$n - n
  adequate <- !is.na(short_by) && short_by <= 0

  reason <- if (is.na(short_by)) {
    "the requirement could not be computed for these inputs"
  } else if (adequate) {
    sprintf("%d rows meets the %d a model of %d parameter(s) needs",
            as.integer(n), as.integer(ceiling(required$n)),
            as.integer(parameters))
  } else {
    sprintf(paste("%d rows is %d short of the %d a model of %d",
                  "parameter(s) needs at %.1f%% prevalence for %.0f%%",
                  "shrinkage"),
            as.integer(n), as.integer(ceiling(short_by)),
            as.integer(ceiling(required$n)), as.integer(parameters),
            100 * prevalence, 100 * shrinkage)
  }

  structure(list(n = as.integer(n), events = as.integer(events),
                 prevalence = prevalence,
                 parameters = as.integer(parameters),
                 events_per_parameter = events / parameters,
                 nagelkerke = nagelkerke,
                 heuristic_shrinkage = heuristic,
                 required_n = required$n,
                 required_events = required$events,
                 short_by = short_by,
                 target_shrinkage = shrinkage,
                 adequate = adequate, reason = reason),
            class = "mm_adequacy")
}

#' @export
print.mm_adequacy <- function(x, ...) {
  cat("<mm_adequacy>  adequate: ", x$adequate, "\n", sep = "")
  cat("  development ", x$n, " rows, ", x$events, " events (",
      sprintf("%.1f%%", 100 * x$prevalence), ")\n", sep = "")
  cat("  parameters  ", x$parameters, " non-intercept, ",
      sprintf("%.1f", x$events_per_parameter),
      " events each (description, not the criterion)\n", sep = "")
  if (!is.na(x$heuristic_shrinkage)) {
    cat("  shrinkage   ", sprintf("%.3f", x$heuristic_shrinkage),
        " expected, heuristic\n", sep = "")
  }
  if (!is.na(x$required_n)) {
    cat("  requires    ", as.integer(ceiling(x$required_n)), " rows, ",
        as.integer(ceiling(x$required_events)), " events (Riley, from the ",
        "fitted R2 of ", sprintf("%.3f", x$nagelkerke), ")\n", sep = "")
  }
  cat("  ", x$reason, "\n", sep = "")
  invisible(x)
}
