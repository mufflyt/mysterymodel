#' Draw each continuous predictor as a straight line and as a spline
#'
#' A diagnostic for the degrees of freedom a continuous predictor is given.
#' Fitting one as a straight line is a modelling decision exactly as much as
#' fitting it with a spline, and it is the decision this package makes by
#' default and says nothing about: `nonlinear` is `NULL` unless an analyst
#' names the predictor. This function makes both allocations visible and
#' quantifies what choosing between them changes.
#'
#' It decides nothing. For each continuous predictor it fits the model twice,
#' once with that predictor linear and once with it splined, everything else
#' held as specified, and reports the predicted risk each implies across the
#' predictor's observed range.
#'
#' @section Why there is no test here, and no recommendation:
#'
#' Fitting a spline, reading the aggregate nonlinear term's p-value and
#' dropping back to a straight line when it is not significant is a pretest
#' estimator: the model's shape becomes a function of the outcome, and the
#' optimism of that choice is corrected by nothing downstream. It is the same
#' error as choosing interactions on the development data and then validating
#' the chosen model as though it had been prespecified. `rms::anova()` prints
#' the aggregate nonlinear row immediately beside the block test, so the
#' temptation is one glance away.
#'
#' The allocation belongs in the analysis plan, decided on what the predictor
#' is rather than on what this cohort's outcome does. Harrell's advice is to
#' spend the degrees of freedom by prespecification, more on predictors
#' expected to matter, within the sample's budget. What this function supplies
#' is the arithmetic for that conversation: the degrees of freedom each
#' allocation costs and the largest risk difference between them.
#'
#' @section What is plotted, and what is deliberately not:
#'
#' Both curves are **adjusted**: every other predictor is held at the
#' reference profile, so the two curves differ only in how this predictor
#' enters. A binned observed event rate is not drawn over them, however
#' natural that looks, because a marginal event rate and an adjusted curve are
#' different quantities and the eye would compare them anyway. A rug of the
#' observed values is drawn instead, which is comparable: it shows where the
#' data actually is, and therefore which parts of either curve rest on
#' nothing.
#'
#' @param project A [mm_project()].
#' @param cohort The cohort. Development rows only, under the same eligibility
#'   rule [mm_model()] fits under.
#' @param predictors Which continuous predictors to draw. Defaults to all of
#'   the project's that can carry a spline.
#' @param knots Knots for the spline arm, as [mm_model()] takes them.
#' @param at Reference profile, as a one-row data frame or a named list. The
#'   default holds continuous predictors at their median and categorical ones
#'   at their most common level, and the profile used is returned.
#' @param n_points Points at which each curve is evaluated.
#' @param plot Draw the panels. `FALSE` returns the curves and draws nothing.
#'
#' @return An object of class `mm_splines`: `curves`, one row per predictor
#'   and evaluation point with the risk each allocation implies; `summary`, one
#'   row per predictor with the degrees of freedom and the largest risk gap
#'   between the two; and the `reference` profile they were drawn at.
#'
#' @examples
#' cohort <- mm_synthetic_cohort(n = 600, prevalence = 0.15, seed = 1978)
#' project <- mm_project("uds", "event", c("age", "bmi", "sex"),
#'                       positive_class = 1, cohort = cohort)
#' shapes <- mm_splines(project, cohort, plot = FALSE)
#' shapes$summary
#' @export
mm_splines <- function(project, cohort, predictors = NULL, knots = 4L,
                       at = NULL, n_points = 120L, plot = TRUE) {
  if (!inherits(project, "mm_project")) {
    stop("`project` must come from mm_project().", call. = FALSE)
  }
  if (!is.data.frame(cohort)) {
    stop("`cohort` must be a data frame.", call. = FALSE)
  }
  parts <- mm_split(project, cohort)
  eligible <- mm_evaluable(project, parts$dev, require_cluster = TRUE)
  frame <- parts$dev[eligible$usable, , drop = FALSE]
  for (p in project$predictors) {
    if (is.factor(frame[[p]])) frame[[p]] <- droplevels(frame[[p]])
  }

  continuous <- Filter(function(p) is.numeric(frame[[p]]),
                       project$predictors)
  wanted <- predictors %||% continuous
  off <- setdiff(wanted, project$predictors)
  if (length(off)) {
    stop("not predictors of this project: ", paste(off, collapse = ", "),
         call. = FALSE)
  }
  not_continuous <- setdiff(wanted, continuous)
  if (length(not_continuous)) {
    stop("a spline needs a continuous predictor, and ",
         paste(not_continuous, collapse = ", "),
         " is categorical. There is no straight line to compare it with.",
         call. = FALSE)
  }
  if (!length(wanted)) {
    stop("this project declares no continuous predictor, so there is no ",
         "spline allocation to draw.", call. = FALSE)
  }

  reference <- mm_reference_profile(project, frame, at)

  curve_rows <- list()
  summary_rows <- list()
  for (p in wanted) {
    ticks <- seq(min(frame[[p]], na.rm = TRUE), max(frame[[p]], na.rm = TRUE),
                 length.out = as.integer(n_points))
    profile <- reference[rep(1L, length(ticks)), , drop = FALSE]
    profile[[p]] <- ticks

    arms <- list(linear = NULL, spline = p)
    risk <- list()
    spent <- c(linear = NA_real_, spline = NA_real_)
    why <- ""
    for (arm in names(arms)) {
      fitted <- tryCatch(
        suppressWarnings(mm_model(project, cohort, nonlinear = arms[[arm]],
                                  knots = knots)),
        error = function(e) conditionMessage(e))
      if (is.character(fitted)) {
        risk[[arm]] <- rep(NA_real_, length(ticks))
        why <- paste0("the ", arm, " arm could not be fitted: ", fitted)
        next
      }
      spent[arm] <- length(stats::coef(fitted$fit)) - 1L
      risk[[arm]] <- mm_predict(fitted, profile)$.pred
    }

    curve_rows[[p]] <- data.frame(
      predictor = p, value = ticks,
      linear = risk$linear, spline = risk$spline,
      stringsAsFactors = FALSE)
    gap <- abs(risk$spline - risk$linear)
    summary_rows[[p]] <- data.frame(
      predictor = p,
      parameters_linear = spent[["linear"]],
      parameters_spline = spent[["spline"]],
      added_parameters = spent[["spline"]] - spent[["linear"]],
      largest_risk_gap = if (all(is.na(gap))) NA_real_ else
        max(gap, na.rm = TRUE),
      at_value = if (all(is.na(gap))) NA_real_ else
        ticks[which.max(gap)],
      note = if (nzchar(why)) why else sprintf(
        paste("drawn over the observed range %.4g to %.4g, every other",
              "predictor at the reference profile"),
        min(ticks), max(ticks)),
      stringsAsFactors = FALSE)
  }

  shapes <- structure(
    list(curves = do.call(rbind, curve_rows),
         summary = do.call(rbind, summary_rows),
         reference = reference, knots = as.integer(knots),
         n_dev = nrow(frame),
         events = sum(mm_event_indicator(frame[[project$outcome]],
                                         project$positive_class)),
         outcome = project$outcome),
    class = "mm_splines")
  row.names(shapes$summary) <- NULL
  if (isTRUE(plot)) mm_draw_splines(shapes, frame)
  shapes
}

#' The profile the spline panels hold everything else at
#'
#' Median for a continuous predictor and the most common level for a
#' categorical one, which is a defensible place to stand and not the only one.
#' It is returned with the curves because an adjusted curve means nothing
#' without the values it was adjusted to.
#'
#' @param project A [mm_project()].
#' @param frame The development rows.
#' @param at Optional override, a named list or one-row data frame.
#' @return A one-row data frame carrying every predictor.
#' @keywords internal
mm_reference_profile <- function(project, frame, at = NULL) {
  middle <- lapply(project$predictors, function(p) {
    column <- frame[[p]]
    if (is.numeric(column)) {
      stats::median(column, na.rm = TRUE)
    } else {
      counts <- table(as.character(column))
      names(counts)[which.max(counts)]
    }
  })
  names(middle) <- project$predictors

  if (!is.null(at)) {
    if (is.data.frame(at)) at <- as.list(at[1L, , drop = FALSE])
    if (!is.list(at) || is.null(names(at)) || !all(nzchar(names(at)))) {
      stop("`at` must be a named list or a one-row data frame.",
           call. = FALSE)
    }
    unknown <- setdiff(names(at), project$predictors)
    if (length(unknown)) {
      stop("`at` names ", paste(unknown, collapse = ", "),
           ", which the project does not declare as a predictor.",
           call. = FALSE)
    }
    for (p in names(at)) middle[[p]] <- at[[p]]
  }

  profile <- as.data.frame(middle, stringsAsFactors = FALSE)
  for (p in project$predictors) {
    if (is.factor(frame[[p]])) {
      profile[[p]] <- factor(as.character(profile[[p]]),
                             levels = levels(frame[[p]]))
      if (is.na(profile[[p]])) {
        stop("`at$", p, "` is not one of the levels this model was fitted ",
             "with: ", paste(levels(frame[[p]]), collapse = ", "),
             call. = FALSE)
      }
    }
  }
  profile
}

#' One panel per predictor, both allocations on the same axes
#' @param shapes An [mm_splines()] result.
#' @param frame The development rows, for the rug.
#' @return `invisible(NULL)`, after drawing.
#' @keywords internal
mm_draw_splines <- function(shapes, frame) {
  panels <- unique(shapes$curves$predictor)
  across <- min(length(panels), 2L)
  down <- ceiling(length(panels) / across)
  op <- graphics::par(mfrow = c(down, across), mar = c(4.2, 4.2, 2.4, 1))
  on.exit(graphics::par(op), add = TRUE)
  for (p in panels) {
    part <- shapes$curves[shapes$curves$predictor == p, , drop = FALSE]
    band <- range(c(part$linear, part$spline), na.rm = TRUE)
    graphics::plot(part$value, part$spline, type = "n", ylim = band,
                   xlab = p, ylab = paste("predicted", shapes$outcome),
                   main = p)
    graphics::lines(part$value, part$linear, lwd = 2, lty = 2)
    graphics::lines(part$value, part$spline, lwd = 2)
    graphics::rug(frame[[p]], col = "#80808060")
    row <- shapes$summary[shapes$summary$predictor == p, ]
    graphics::legend("topleft", bty = "n", lwd = 2, lty = c(2, 1),
                     legend = c(sprintf("linear, %d parameter(s)",
                                        row$parameters_linear),
                                sprintf("spline, %d parameter(s)",
                                        row$parameters_spline)))
    graphics::mtext(sprintf("largest gap %.4f in risk", row$largest_risk_gap),
                    side = 3, line = 0.2, cex = 0.75, adj = 1)
  }
  invisible(NULL)
}

#' @export
print.mm_splines <- function(x, ...) {
  cat("<mm_splines>  ", x$n_dev, " rows, ", x$events, " events, ",
      x$knots, " knots\n", sep = "")
  for (i in seq_len(nrow(x$summary))) {
    row <- x$summary[i, ]
    cat(sprintf("  %-10s %d -> %d parameter(s), largest risk gap %.4f at %s\n",
                row$predictor, row$parameters_linear, row$parameters_spline,
                row$largest_risk_gap, format(row$at_value, digits = 4)))
  }
  cat("  reference  ",
      paste(sprintf("%s = %s", names(x$reference),
                    vapply(x$reference, function(v)
                      format(v, digits = 4), character(1))),
            collapse = ", "), "\n", sep = "")
  cat("  Both curves are adjusted to that profile. The allocation is a\n")
  cat("  prespecified choice: this draws what each one implies and tests\n")
  cat("  nothing, because choosing the shape from the outcome is a\n")
  cat("  decision no later resampling here corrects.\n")
  invisible(x)
}
