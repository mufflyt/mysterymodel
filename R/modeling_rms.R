#' Fit the declared model with rms
#'
#' Builds the formula from the project, fits it with [rms::lrm()], and keeps
#' everything a later step needs: the fit, its `datadist`, the formula it was
#' actually given, a prediction schema and a fingerprint of the coefficients.
#'
#' `x` and `y` are kept on the fit, because validation and calibration need
#' them and a fit without them fails later for reasons that do not name this
#' decision. That is the only patient-level retention: the design matrix the
#' model was fitted on and the outcome it was fitted to.
#'
#' Nothing else of the cohort survives, and the mechanism is worth naming
#' because the default behaviour is the opposite. A formula keeps the
#' environment it was built in, `rms::lrm()` stores that environment on
#' `fit$terms` and `fit$sformula`, and a formula built in this function's own
#' frame would hold the cohort, the development rows and the split. The
#' identifier column in particular is in none of them, so a saved model cannot
#' carry patient identifiers into a place the data was never meant to go. The
#' formula is built in `baseenv()` to keep that true.
#'
#' A predictor that reproduces the outcome is refused. A model given its own
#' outcome under another name reports near-perfect discrimination, which reads
#' as success, and the by-name check that `outcome` is not among `predictors`
#' cannot see a renamed copy. Separation that is not duplication is reported
#' instead of refused, because in a small cohort it can be real. See
#' [mm_leakage()], including what it cannot tell you.
#'
#' Strong hierarchy is enforced rather than assumed: an interaction is refused
#' unless both of its main effects are in the project's predictors. The
#' specification requires that an interaction only be usable with its
#' constituent main effects, and a formula is the last place to find out.
#'
#' Which rows are modelled is decided once, before anything is fitted, and the
#' `datadist`, the fit and the prediction schema are all built from that one
#' frame. `rms` would otherwise drop a row with a missing model variable at fit
#' time, leaving three parts of the same object describing three different
#' samples: the fit estimated on the complete rows, the schema taking its
#' ranges and levels from the supplied ones, and the datadist taking the
#' limits that set a nomogram's drawn axis. A value no fitted row carried then
#' came back labelled as interpolation, and the printed nomogram reached
#' values the model was never estimated on.
#'
#' The difference is reported rather than absorbed, as `n_supplied`,
#' `n_incomplete` and `incomplete_by`, and warned about. It matters most for
#' the sample-size gate, which would otherwise judge a sample larger than the
#' one that exists and so be most lenient exactly where it should be
#' strictest. Deciding the analysis sample belongs in [mm_clean()], where the
#' exclusion reaches the flow diagram, not in `na.action`.
#'
#' A factor level carried only by dropped rows is removed and named in
#' `lost_levels`. It has no rows left to estimate it from, `rms` answers one
#' with a singular Hessian whose message identifies neither the variable nor
#' the level, and leaving it in the schema would let [mm_predict()] admit a
#' level the model cannot score.
#'
#' @param project A [mm_project()] configuration.
#' @param cohort The development data. When the project declares a split, only
#'   rows below `split_at` are used, and the held-out rows are returned
#'   untouched for later scoring.
#' @param nonlinear Continuous predictors to fit with restricted cubic
#'   splines. `NULL` takes the project's prespecified `nonlinear`, which is
#'   where the choice belongs. Supplying it here overrides the plan and the
#'   departure is recorded on the returned object and warned about, because a
#'   model whose shape differs from the written plan is a finding and not a
#'   detail.
#' @param interactions Prespecified interaction blocks. `NULL` takes the
#'   project's, with departures recorded the same way.
#' @param reference Comparison categories for categorical predictors. `NULL`
#'   takes the project's. Applied before the `datadist`, the fit and the
#'   schema, so every one of them agrees about which level is the baseline.
#' @param knots Knots for each spline term. `NULL` takes the project's.
#' @param check_leakage Scan the development predictors for duplication of the
#'   outcome. `TRUE` for a declared model. [mm_full_process()] passes `FALSE`
#'   when refitting inside a resample, because the declared cohort has already
#'   been scanned and a resample is a subset of it, so a match there is a
#'   property of the draw rather than of the analysis. It is not an override:
#'   there is no way to reach it with a cohort that has not been scanned.
#'
#' @return An object of class `mm_model`.
#'
#' @examples
#' cohort <- mm_synthetic_cohort(n = 300, seed = 1)
#' project <- mm_project("uds", "event",
#'                       c("age", "bmi", "sex", "prior_uti"),
#'                       cohort = cohort)
#' fit <- mm_model(project, cohort, nonlinear = "age",
#'                 interactions = list(c("prior_uti", "sex")))
#' fit
#' @export
mm_model <- function(project, cohort, nonlinear = NULL,
                     interactions = NULL, reference = NULL, knots = NULL,
                     check_leakage = TRUE) {
  if (!inherits(project, "mm_project")) {
    stop("`project` must come from mm_project().", call. = FALSE)
  }
  # The plan is the project's. An argument here overrides it, and overriding
  # a written plan is reported rather than absorbed.
  departures <- character(0)
  note_departure <- function(what, planned, used) {
    sprintf("%s: the project prespecifies %s and this fit used %s", what,
            if (!length(planned)) "none" else
              paste(planned, collapse = ", "),
            if (!length(used)) "none" else paste(used, collapse = ", "))
  }
  # A project that declares nothing has no plan to depart from: an unset
  # field is unset, not a declaration that every continuous predictor is
  # straight. Only a plan that was written down can be departed from, which
  # is also what keeps a fit from being scolded for a default nobody chose.
  declared_shape <- !is.null(project$nonlinear)
  if (is.null(nonlinear)) {
    nonlinear <- project$nonlinear
  } else if (declared_shape &&
             !identical(sort(nonlinear), sort(project$nonlinear))) {
    departures <- c(departures, note_departure(
      "nonlinear", project$nonlinear, nonlinear))
  }
  if (is.null(interactions)) {
    interactions <- project$interactions
  } else if (!is.null(project$interactions)) {
    label <- function(blocks) sort(vapply(blocks %||% list(), function(b)
      paste(sort(b), collapse = ":"), character(1)))
    if (!identical(label(interactions), label(project$interactions))) {
      departures <- c(departures, note_departure(
        "interactions", label(project$interactions), label(interactions)))
    }
  }
  if (is.null(reference)) {
    reference <- project$reference
  } else if (!is.null(project$reference)) {
    flat <- function(r) {
      if (!length(r)) return(character(0))
      sort(sprintf("%s=%s", names(r), unlist(r)))
    }
    if (!identical(flat(reference), flat(project$reference))) {
      departures <- c(departures, note_departure(
        "reference", flat(project$reference), flat(reference)))
    }
  }
  if (is.null(knots)) {
    knots <- project$knots %||% 4L
  } else if (declared_shape &&
             !identical(as.integer(knots), as.integer(project$knots))) {
    # Knots only mean anything beside a declared spline, so they are a
    # departure only when the plan declared one.
    departures <- c(departures, note_departure(
      "knots", project$knots, knots))
  }
  if (length(departures)) {
    warning("this fit departs from the project's written plan. ",
            paste(departures, collapse = "; "),
            ". The plan is what a reviewer checks against a protocol, so the ",
            "departure is recorded on the returned object as `departures` ",
            "rather than left to be reconstructed from the call.",
            call. = FALSE)
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
  asked <- character(0)
  for (ia in pairs) {
    if (length(ia) != 2L) {
      stop("each interaction must name exactly two predictors.",
           call. = FALSE)
    }
    # A formula reduces `a:a` to `a` and collapses a block asked for twice,
    # so both used to be accepted and add no term. The parameter budget then
    # counted a block the model does not contain.
    if (identical(ia[1], ia[2])) {
      stop("interaction ", ia[1], ":", ia[2], " crosses a predictor with ",
           "itself, which a formula reduces to the main effect, so the model ",
           "would not contain the block it reports. Curvature belongs in ",
           "`nonlinear`.", call. = FALSE)
    }
    key <- paste(sort(ia), collapse = ":")
    if (key %in% asked) {
      stop("interaction ", key, " is listed more than once. Reversing a ",
           "pair does not make a different interaction, and a formula keeps ",
           "one copy, so the model would not contain the two blocks it ",
           "reports.", call. = FALSE)
    }
    asked <- c(asked, key)
    missing_main <- setdiff(ia, project$predictors)
    if (length(missing_main)) {
      stop("interaction ", paste(ia, collapse = ":"), " needs its main ",
           "effect(s) ", paste(missing_main, collapse = ", "),
           " among the predictors. An interaction without its main ",
           "effects is not interpretable.", call. = FALSE)
    }
  }

  # Checked here too, because a project may have been written without a
  # cohort to check it against, and rms answers an ordered factor from inside
  # Design() with advice about a global option the analyst never set.
  ordered_predictors <- Filter(function(p) is.ordered(cohort[[p]]) &&
                                 !is.numeric(levels(cohort[[p]])),
                               project$predictors)
  if (length(ordered_predictors)) {
    stop("ordered factor(s) among the predictors: ",
         paste(ordered_predictors, collapse = ", "),
         ". `rms::lrm()` refuses one with non-numeric levels. Drop the ",
         "ordering with `factor(x, ordered = FALSE)` for one parameter per ",
         "level, or score the levels and enter the column as numeric for a ",
         "trend. See mm_project() for why the choice is not made here.",
         call. = FALSE)
  }

  parts <- mm_split(project, cohort)
  supplied <- parts$dev

  y_supplied <- mm_event_indicator(supplied[[project$outcome]],
                                   project$positive_class)
  if (length(unique(stats::na.omit(y_supplied))) < 2L) {
    stop("the outcome does not vary in the development rows.",
         call. = FALSE)
  }

  # Which rows are modelled is decided once, here, and the datadist, the fit
  # and the schema are all built from that one frame. Leaving it to
  # `na.action` at fit time decided it three times over: `rms` would fit the
  # complete rows while the datadist took its limits and the schema took its
  # ranges and levels from rows the model never saw, so a value no fitted row
  # carried came back labelled as interpolation and the drawn nomogram
  # reached axis values the model was never estimated on.
  eligible <- mm_evaluable(project, supplied, require_cluster = TRUE)
  dev <- supplied[eligible$usable, , drop = FALSE]
  y <- y_supplied[eligible$usable]
  n_incomplete <- eligible$n_excluded
  by_variable <- eligible$by_variable

  if (n_incomplete > 0L) {
    warning(n_incomplete, " of ", nrow(supplied), " development row(s) were ",
            "dropped before fitting, incomplete on ",
            paste(sprintf("%s (%d)", names(by_variable), by_variable),
                  collapse = ", "),
            ". Every count reported here describes the ", nrow(dev),
            " rows that were fitted, not the ", nrow(supplied), " supplied. ",
            "Make the exclusion a rule in mm_clean() so it reaches the flow ",
            "diagram, or impute, rather than leaving the analysis sample to ",
            "be settled by na.action.",
            if (!is.null(project$cluster_id) &&
                project$cluster_id %in% names(by_variable))
              paste0(" The ", project$cluster_id, " column is required ",
                     "because this project declares a cluster: a row that ",
                     "cannot be assigned to a patient cannot take part in ",
                     "clustered resampling, and a bootstrap over a subset of ",
                     "the fitted rows corrects the optimism of a different ",
                     "model from the one reported."),
            call. = FALSE)
  }

  # A factor level carried only by dropped rows has no rows left to estimate
  # it from. `rms` responds to one with a singular Hessian, whose message
  # names neither the variable nor the level, so the level is removed here and
  # named. Removing it is also what makes mm_predict() refuse it later: a
  # level the model cannot score must not be in the schema that admits it.
  lost <- list()
  # A factor's first level is the baseline every other coefficient for it is
  # measured against. Dropping a level that happens to be first moves that
  # baseline, and the coefficient names do not change, so two fits of the
  # same declared model can report `indication=prolapse` against two
  # different comparison categories. The level loss was already reported; the
  # consequence was not.
  reference_moved <- list()
  for (p in project$predictors) {
    if (!is.factor(supplied[[p]]) && !is.character(supplied[[p]])) next
    was <- levels(factor(supplied[[p]]))
    gone <- setdiff(was, levels(factor(dev[[p]])))
    if (length(gone)) lost[[p]] <- gone
    if (is.factor(dev[[p]])) dev[[p]] <- droplevels(dev[[p]])
    now <- levels(factor(dev[[p]]))
    # A declared baseline is applied here, before the datadist, the fit and
    # the schema, so all three agree about which level is first. A declared
    # one that no eligible row carries is refused rather than quietly
    # replaced by the next level along, which is the whole reason for
    # declaring it.
    wanted <- reference[[p]]
    if (!is.null(wanted)) {
      if (!as.character(wanted) %in% now) {
        stop("`reference$", p, "` declares the baseline \"", wanted,
             "\", and no row that survived eligibility carries it",
             if (length(gone) && as.character(wanted) %in% gone)
               ": it left with the rows dropped for incompleteness" else "",
             ". The levels left are ", paste(now, collapse = ", "),
             ". A declared baseline is refused rather than replaced, ",
             "because every coefficient for this predictor is measured ",
             "against it.", call. = FALSE)
      }
      dev[[p]] <- stats::relevel(factor(dev[[p]]), ref = as.character(wanted))
      now <- levels(dev[[p]])
    }
    if (length(now) && !identical(was[1], now[1]) && is.null(wanted)) {
      # Only an undeclared move is a finding. A declared one is the plan.
      reference_moved[[p]] <- c(from = was[1], to = now[1])
    }
  }
  if (length(lost)) {
    warning("level(s) carried only by the dropped rows cannot be estimated ",
            "and are not in this model: ",
            paste(sprintf("%s = %s", names(lost),
                          vapply(lost, paste, character(1),
                                 collapse = "/")),
                  collapse = "; "),
            ". mm_predict() will refuse them by name rather than score them.",
            if (length(reference_moved))
              paste0(" The comparison category moved with them: ",
                     paste(vapply(names(reference_moved), function(v)
                       sprintf("%s is now measured against %s and not %s", v,
                               reference_moved[[v]][["to"]],
                               reference_moved[[v]][["from"]]),
                       character(1)), collapse = "; "),
                     ". Every other coefficient for that predictor means ",
                     "something different from a fit where the level ",
                     "survived, under the same name."),
            call. = FALSE)
  }

  if (length(unique(y)) < 2L) {
    stop("the outcome does not vary among the ", nrow(dev),
         " complete development row(s), though it varies among the ",
         nrow(supplied), " supplied. The rows carrying the other outcome ",
         "value are incomplete on ",
         paste(names(by_variable), collapse = ", "), ".", call. = FALSE)
  }
  dev[[".mm_y"]] <- y

  # Leakage is checked here and not in mm_project(), because here is the first
  # point at which the effective development frame exists: after the split,
  # after the complete-case eligibility DEC-003 settled, and after a level
  # carried only by excluded rows has gone. Checking the supplied cohort would
  # answer a question about rows the model will not see.
  leakage <- if (isTRUE(check_leakage)) {
    found <- mm_leakage(project, dev, y = y)
    mm_report_leakage(found, project$outcome)
    found
  } else list()

  term_of <- function(p) {
    if (p %in% (nonlinear %||% character(0))) {
      sprintf("rms::rcs(%s, %d)", p, as.integer(knots))
    } else p
  }
  rhs <- vapply(project$predictors, term_of, character(1))
  for (ia in pairs) {
    rhs <- c(rhs, paste(term_of(ia[1]), term_of(ia[2]), sep = ":"))
  }
  # Built in `baseenv()`, not in this frame. `stats::as.formula()` defaults to
  # the calling frame, which here holds `cohort`, `dev`, `parts` and `y`, and
  # `rms::lrm()` keeps that environment on `fit$terms` and `fit$sformula`. A
  # model built the default way therefore carries the whole cohort, patient
  # identifiers included, into anything that saves it.
  form <- stats::as.formula(
    paste(".mm_y ~", paste(rhs, collapse = " + ")), env = baseenv())

  dd <- rms::datadist(dev[, project$predictors, drop = FALSE])
  old <- options(datadist = dd)
  on.exit(options(old), add = TRUE)

  fit <- rms::lrm(form, data = dev, x = TRUE, y = TRUE)

  # Convergence first. A fit that failed leaves no usable `y` on the object,
  # so the row-count guard below would fire and blame a silent row drop for
  # what is really a likelihood with no interior maximum, which is the
  # commonest way a small cohort refuses an interaction.
  if (isTRUE(fit$fail)) {
    stop("rms could not fit this model: ", if (length(pairs))
      paste0("the design includes ",
             paste(vapply(pairs, paste, character(1), collapse = ":"),
                   collapse = ", "), ", and ") else "",
      "the estimate did not converge, which a singular Hessian usually ",
      "means: some combination of the terms separates the outcome, so the ",
      "likelihood has no interior maximum and there is no estimate to ",
      "report. Fewer terms, or a cohort in which every combination carries ",
      "both outcomes, is what fixes it. mm_interactions() reports this per ",
      "block rather than raising it.", call. = FALSE)
  }

  # `dev` is already complete on every model variable, so this should never
  # fire. It is here because a silent further drop would put the fit and the
  # counts back out of step, which is the whole defect this ordering fixes.
  if (length(fit$y) != nrow(dev)) {
    stop("rms dropped a further ", nrow(dev) - length(fit$y),
         " row(s) from a frame that is complete on ",
         paste(c(project$outcome, project$predictors, project$cluster_id),
               collapse = ", "),
         ". The reported sample would no longer be the fitted one.",
         call. = FALSE)
  }
  n_fitted <- nrow(dev)
  events_fitted <- sum(y)

  # Section 19: the parameter budget is reported, and an overly ambitious
  # one warns rather than passing quietly. Splines and interactions are
  # counted, because they are the terms that get spent without being noticed.
  adequacy <- mm_adequacy(
    n = n_fitted, events = events_fitted,
    parameters = length(stats::coef(fit)) - 1L,
    nagelkerke = unname(fit$stats["R2"]),
    likelihood_ratio = unname(fit$stats["Model L.R."]))
  if (!isTRUE(adequacy$adequate)) {
    warning("the development sample may be too small for this model: ",
            adequacy$reason, ". Coefficients from a sample this size are ",
            "expected to be overfitted; see the adequacy element of the ",
            "returned object.", call. = FALSE)
  }

  structure(
    list(project    = project,
         fit        = fit,
         datadist   = dd,
         formula    = form,
         nonlinear  = nonlinear,
         interactions = pairs,
         knots      = as.integer(knots),
         departures = departures,
         n_dev      = n_fitted,
         events_dev = events_fitted,
         n_supplied = nrow(supplied),
         n_incomplete = n_incomplete,
         incomplete_by = by_variable,
         lost_levels = lost,
         reference_moved = reference_moved,
         reference = reference,
         leakage = leakage,
         eligibility = eligible[setdiff(names(eligible), "usable")],
         n_held     = nrow(parts$held),
         adequacy   = adequacy,
         schema     = mm_schema(project, dev),
         fingerprint = digest::digest(
           list(coef = unname(stats::coef(fit)),
                formula = deparse(form)), algo = "sha256"),
         # Which rows were fitted, as a hash rather than a copy. A row count
         # cannot tell a cohort from a different cohort of the same size, and
         # an "apparent" number computed on rows the model never saw is not
         # apparent. The columns are the ones the analysis reads, so a change
         # to any of them is a different development sample.
         development = mm_sample_digest(project, dev)),
    class = "mm_model"
  )
}

#' @export
print.mm_model <- function(x, ...) {
  cat("<mm_model: ", x$project$slug, ">\n", sep = "")
  cat("  formula    ", deparse(x$formula), "\n", sep = "")
  if (length(x$departures)) {
    for (one in x$departures) {
      cat("  DEPARTS    ", one, "\n", sep = "")
    }
  }
  cat("  developed  ", x$n_dev, " rows, ", x$events_dev, " events\n",
      sep = "")
  if (x$n_incomplete > 0L) {
    cat("  dropped    ", x$n_incomplete, " of ", x$n_supplied,
        " supplied row(s), incomplete on ",
        paste(names(x$incomplete_by), collapse = ", "),
        "\n", sep = "")
  }
  for (v in names(x$reference_moved)) {
    cat("  BASELINE   ", v, " is measured against ",
        x$reference_moved[[v]][["to"]], ", not ",
        x$reference_moved[[v]][["from"]], ", which left with the dropped ",
        "rows\n", sep = "")
  }
  if (x$n_held > 0L) {
    cat("  held out   ", x$n_held, " rows\n", sep = "")
  }
  cat("  parameters ", length(stats::coef(x$fit)) - 1L,
      " non-intercept", if (isTRUE(x$adequacy$adequate)) "" else
        sprintf(", %d short of the sample they need",
                as.integer(ceiling(x$adequacy$short_by))),
      "\n", sep = "")
  cat("  apparent C ", sprintf("%.4f", unname(x$fit$stats["C"])), "\n",
      sep = "")
  cat("  fingerprint ", substr(x$fingerprint, 1, 16), "\n", sep = "")
  invisible(x)
}


#' Turn an outcome column into a 0/1 indicator
#'
#' @param values The outcome column.
#' @param positive_class The event level, or NULL to infer.
#' @return Integer vector of 0 and 1.
#' @keywords internal
mm_event_indicator <- function(values, positive_class = NULL) {
  if (!is.null(positive_class)) {
    return(as.integer(as.character(values) == as.character(positive_class)))
  }
  if (is.numeric(values) && all(stats::na.omit(values) %in% c(0, 1))) {
    return(as.integer(values))
  }
  lev <- sort(unique(as.character(stats::na.omit(values))))
  if (length(lev) != 2L) {
    stop("cannot infer the event level from ", length(lev),
         " distinct values. Set `positive_class` in mm_project().",
         call. = FALSE)
  }
  as.integer(as.character(values) == lev[2])
}

#' Record what a deployed prediction is allowed to receive
#'
#' @param project A [mm_project()].
#' @param dev The development rows.
#' @return A list describing each predictor.
#' @keywords internal
mm_schema <- function(project, dev) {
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

#' Which rows a complete-data model can be fitted to, or scored and counted on
#'
#' One rule, read by fitting and by both kinds of validation, so that the
#' sample a model was estimated on and the sample it is judged against cannot
#' be decided twice and differently. The breakdown is part of the return value
#' rather than a side effect, because the exclusions belong in the report.
#'
#' A missing predictor and a missing outcome are counted apart, and the overlap
#' separately. They are different exclusions: one is a patient who cannot be
#' scored, the other a patient who can be scored but contributes nothing to a
#' performance estimate. Neither is an event, and treating a missing outcome as
#' a non-event is the specific error this separation exists to prevent.
#'
#' This is complete-case analysis, which is a computational strategy and not a
#' guarantee. Missingness may be informative, the more so in the small clinical
#' cohorts this package is for, so the counts are reported everywhere they
#' apply rather than summarised away. Multiple imputation is the answer and is
#' not in this package yet.
#'
#' @param project A [mm_project()].
#' @param frame Rows to assess.
#' The outcome must be observed. Every caller is fitting a model or scoring
#' one into a metric, and both need it; a prediction wants no outcome and does
#' not come through here, [mm_predict()] selects its own rows.
#'
#' @param require_cluster Whether a declared `cluster_id` must be observed.
#'   `TRUE` for a development frame, because a row that cannot be assigned to a
#'   patient cannot take part in clustered resampling, and a bootstrap run on a
#'   subset of the rows the model was fitted to corrects the optimism of a
#'   different model from the one reported. `FALSE` for held-out rows, which are
#'   scored once and never resampled, so an identifier they lack costs nothing.
#'
#' @return A list: the `usable` mask, the counts `n_total`, `n_scored`,
#'   `n_excluded`, `missing_predictor`, `missing_outcome`, `missing_both`,
#'   and `by_variable`.
#' @keywords internal
mm_evaluable <- function(project, frame, require_cluster = FALSE) {
  if (!is.data.frame(frame)) {
    stop("`frame` must be a data frame.", call. = FALSE)
  }
  needs_cluster <- isTRUE(require_cluster) && !is.null(project$cluster_id)
  wanted <- c(project$predictors, project$outcome,
              if (needs_cluster) project$cluster_id)
  absent <- setdiff(wanted, names(frame))
  if (length(absent)) {
    stop("not columns of the frame: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }

  n <- nrow(frame)
  blank <- function(cols) {
    if (!length(cols)) return(rep(FALSE, n))
    Reduce(`|`, lapply(cols, function(v) is.na(frame[[v]])))
  }
  no_predictor <- blank(c(project$predictors,
                          if (needs_cluster) project$cluster_id))
  no_outcome <- blank(project$outcome)

  by_variable <- vapply(wanted, function(v) sum(is.na(frame[[v]])),
                        integer(1))

  usable <- !no_predictor & !no_outcome
  list(usable              = usable,
       n_total             = n,
       n_scored            = sum(usable),
       n_excluded          = sum(!usable),
       missing_predictor   = sum(no_predictor & !no_outcome),
       missing_outcome     = sum(no_outcome & !no_predictor),
       missing_both        = sum(no_predictor & no_outcome),
       by_variable         = by_variable[by_variable > 0L])
}

#' The exclusions, as a sentence for the note column
#' @param e An [mm_evaluable()] report.
#' @return A string, or `""` when nothing was excluded.
#' @keywords internal
mm_eligibility_note <- function(e) {
  if (e$n_excluded == 0L) return("")
  parts <- character(0)
  if (e$missing_predictor > 0L) {
    parts <- c(parts, sprintf("%d for a missing predictor",
                              e$missing_predictor))
  }
  if (e$missing_outcome > 0L) {
    parts <- c(parts, sprintf("%d for a missing outcome",
                              e$missing_outcome))
  }
  if (e$missing_both > 0L) {
    parts <- c(parts, sprintf("%d for both", e$missing_both))
  }
  sprintf(paste("%d of %d row(s) scored, %d excluded (%s; %s).",
                "Complete case, so these estimates assume the exclusions",
                "are uninformative, which is an assumption and not a",
                "finding"),
          e$n_scored, e$n_total, e$n_excluded,
          paste(parts, collapse = ", "),
          paste(sprintf("%s %d", names(e$by_variable), e$by_variable),
                collapse = ", "))
}

#' A fingerprint of the rows an analysis was run on
#'
#' Factors are hashed as their values and not as their level sets, because
#' [mm_model()] drops a level no fitted row carries and a caller re-deriving
#' the same frame has not. Numeric columns are hashed as they are, so nothing
#' is rounded on the way in.
#'
#' @param project A [mm_project()].
#' @param frame The rows.
#' @return A SHA-256 string. Not a copy of the data, and not invertible.
#' @keywords internal
mm_sample_digest <- function(project, frame) {
  vars <- c(project$outcome, project$predictors, project$cluster_id)
  vars <- intersect(vars, names(frame))
  digest::digest(
    lapply(frame[, vars, drop = FALSE], function(v)
      if (is.factor(v) || is.character(v)) as.character(v) else v),
    algo = "sha256")
}

#' Refuse a cohort that is not the one the model was developed on
#'
#' A row count cannot distinguish a cohort from a different cohort of the same
#' size, and every basis [mm_validate()] reports describes the development
#' sample. Scoring a different one and calling the result apparent is not a
#' smaller error than scoring none.
#'
#' The comparison is order sensitive, because the pairing of predictors to
#' outcome is what a c-statistic measures: the same rows in a different order
#' are the same sample, but nothing cheap tells that apart from the same
#' predictor rows carrying permuted outcomes, which is a different sample
#' entirely. So a reordered cohort is refused too, and the message says so.
#'
#' @param model A [mm_model()].
#' @param dev The development rows a caller has re-derived.
#' @param what What the caller is about to do, for the message.
#' @return `TRUE`, invisibly, or an error.
#' @keywords internal
mm_same_development <- function(model, dev, what) {
  project <- model$project
  if (nrow(dev) != model$n_dev) {
    stop("the development rows of `cohort` give ", nrow(dev),
         " evaluable row(s), and the model was fitted on ", model$n_dev,
         ". This is not the cohort the model was developed on, so ", what,
         " would describe a different sample from the fit.", call. = FALSE)
  }
  seen <- mm_sample_digest(project, dev)
  if (!identical(seen, model$development)) {
    stop("`cohort` has the same number of evaluable development rows as the ",
         "model was fitted on, and they are not the same rows: the ",
         "development fingerprint is ", substr(seen, 1, 12), " and the model ",
         "was fitted on ", substr(model$development, 1, 12), ". ", what,
         " would be computed on data the model never saw. If only the row ",
         "order changed, pass the cohort in the order it was fitted in.",
         call. = FALSE)
  }
  invisible(TRUE)
}

#' Split a cohort the way the project declares
#'
#' One place, so that fitting, validation and held-out scoring cannot disagree
#' about which rows are development.
#'
#' @param project A [mm_project()].
#' @param cohort The cohort.
#' @return A list with `dev` and `held`.
#' @keywords internal
mm_split <- function(project, cohort) {
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
