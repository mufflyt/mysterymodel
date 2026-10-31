#' Draw the nomogram, and prove it agrees with the model
#'
#' Builds the canonical [rms::nomogram()] from the exact fitted model, with the
#' same `datadist` it was fitted under, then reads the drawn nomogram back the
#' way a clinician reads it and checks that the answer matches [mm_predict()].
#'
#' A nomogram that disagrees with the model it was drawn from is worse than no
#' nomogram, because it is a published instrument giving wrong risks. So the
#' agreement is asserted rather than assumed, which is what the specification's
#' nomogram contract requires.
#'
#' The check is made at the nomogram's own tabulated tick values, where
#' agreement holds to machine precision. Reading *between* ticks is a different
#' matter: a spline term curves between printed ticks and linear interpolation
#' across them does not, so an off-tick reading carries the axis's resolution
#' error. That is a property of every printed nomogram and of the clinician
#' reading it, not a defect here. `reading_error` bounds it: no reading between
#' the printed ticks can differ from [mm_predict()] by more than that figure.
#' See [mm_reading_error()] for how a bound is reached without searching the
#' joint space, and for the three things it does not cover.
#'
#' @param model A [mm_model()].
#' @param out_dir Directory for the exported files. `NULL` draws nothing.
#' @param tolerance Largest absolute difference in predicted risk tolerated
#'   between the nomogram and [mm_predict()] at tabulated values.
#' @param width,height Inches. The default is the landscape shape the
#'   specification asks for.
#' @param fun_at Risk ticks for the printed risk axis.
#'
#' @return An object of class `mm_nomogram`.
#'
#' @examples
#' cohort <- mm_synthetic_cohort(n = 300, seed = 1)
#' project <- mm_project("uds", "event", c("age", "bmi", "sex"),
#'                       cohort = cohort)
#' fit <- mm_model(project, cohort, nonlinear = "age")
#' nom <- mm_nomogram(fit, out_dir = NULL)
#' nom
#' @export
mm_nomogram <- function(model, out_dir = NULL, tolerance = 1e-6,
                        width = 13, height = 9, fun_at = NULL) {
  if (!inherits(model, "mm_model")) {
    stop("`model` must come from mm_model().", call. = FALSE)
  }
  undrawable <- mm_undrawable_blocks(model)
  if (length(undrawable)) {
    stop("this model cannot be drawn as a nomogram. ",
         paste(undrawable, collapse = "; "),
         ". A nomogram gives each predictor one axis and adds the points, ",
         "which can represent an interaction only by drawing a separate axis ",
         "per level of a categorical partner. Two continuous predictors have ",
         "no levels to separate, so `rms::nomogram()` would need one of them ",
         "fixed at stated settings and would then draw a different ",
         "instrument: one axis per setting, correct only at those values. ",
         "The model itself is sound and mm_predict() and mm_validate() work ",
         "on it normally. Present it as a calculator, which is what the ",
         "specification asks for where complexity outgrows the page, and ",
         "keep the model as fitted rather than reshaping it to fit a ",
         "drawing.", call. = FALSE)
  }

  old <- options(datadist = model$datadist)
  on.exit(options(old), add = TRUE)

  args <- list(fit = model$fit, fun = stats::plogis,
               funlabel = "Predicted risk")
  if (!is.null(fun_at)) args$fun.at <- fun_at
  nom <- do.call(rms::nomogram, args)

  axes <- mm_axis_names(nom)
  profiles <- mm_tick_profiles(nom, model)
  from_nom <- vapply(seq_len(nrow(profiles)),
                     function(i) mm_nomogram_risk(nom,
                                                  profiles[i, , drop = FALSE]),
                     numeric(1))
  totals <- vapply(seq_len(nrow(profiles)),
                   function(i) mm_nomogram_points(nom,
                                                  profiles[i, , drop = FALSE]),
                   numeric(1))
  from_model <- mm_predict(model, profiles)$.pred
  gap <- abs(from_nom - from_model)
  worst <- max(gap, na.rm = TRUE)

  if (worst > tolerance) {
    stop("the nomogram disagrees with mm_predict() by ",
         format(worst, digits = 3), " at a tabulated profile, over the ",
         "tolerance of ", format(tolerance), ". A nomogram that does not ",
         "reproduce its own model must not be published.", call. = FALSE)
  }

  reading <- mm_reading_error(nom, model)

  files <- character(0)
  if (!is.null(out_dir)) {
    files <- mm_nomogram_export(nom, out_dir, model$project$slug,
                               width, height)
  }

  exclusive <- mm_exclusive_axes(nom, model)
  structure(list(nomogram = nom, axes = axes,
                 profiles_checked = nrow(profiles),
                 worst_disagreement = worst, tolerance = tolerance,
                 off_axis = sum(mm_off_axis(nom, totals)),
                 reading_error = reading$bound,
                 reading_error_lp = reading$lp,
                 reading_error_by_axis = reading$by_axis,
                 exclusive_axes = exclusive,
                 n_axes = length(axes),
                 n_predictors = length(model$project$predictors),
                 files = files, fingerprint = model$fingerprint),
            class = "mm_nomogram")
}

#' Interaction blocks a nomogram cannot represent
#'
#' A nomogram gives each predictor one axis and sums the points, so an
#' interaction only reaches the page as a separate axis per level of a
#' categorical partner. Two continuous predictors have no levels to separate
#' by, and `rms::nomogram()` says so through its `interact` argument, which
#' this package does not pass: the resulting error names an argument the
#' analyst never used and nothing about what to do.
#'
#' Checked before anything is drawn, so the refusal names the block rather
#' than arriving from inside rms.
#'
#' @param model A [mm_model()].
#' @return A character vector describing each undrawable block, empty when
#'   every block can be drawn.
#' @keywords internal
mm_undrawable_blocks <- function(model) {
  blocks <- model$interactions
  if (!length(blocks)) return(character(0))
  continuous <- function(p) {
    spec <- model$schema$predictors[[p]]
    !is.null(spec) && identical(spec$type, "numeric")
  }
  found <- vapply(blocks, function(pair) all(vapply(pair, continuous,
                                                    logical(1))),
                  logical(1))
  if (!any(found)) return(character(0))
  vapply(blocks[found], function(pair) sprintf(
    paste("the block %s crosses two continuous predictors, and both %s and",
          "%s are continuous in this model"),
    paste(pair, collapse = " by "), pair[1], pair[2]), character(1))
}

#' Groups of axes of which exactly one applies to any patient
#'
#' An interaction makes `rms` draw one axis per level of the categorical
#' partner, labelled `sex (prior_uti=no)` and `sex (prior_uti=yes)`. The
#' arithmetic handles it: [mm_nomogram_points()] matches every value an axis
#' holds fixed, so exactly one contributes and the read-back agrees with the
#' model to machine precision.
#'
#' A clinician reading the printed sheet has no such guard. They see two axes
#' both labelled `sex` and nothing on the page stops them scoring both, which
#' is an error no check inside this package can catch because it happens on
#' paper. So the groups are named in the returned object and in what it
#' prints, for whoever writes the caption.
#'
#' @param nom An `rms` nomogram.
#' @param model A [mm_model()].
#' @return A list, one element per group of two or more mutually exclusive
#'   axes, naming the axes and the predictors that separate them.
#' @keywords internal
mm_exclusive_axes <- function(nom, model) {
  axes <- mm_axis_names(nom)
  if (length(axes) < 2L) return(list())
  carried <- lapply(axes, function(ax)
    sort(intersect(names(nom[[ax]]), model$project$predictors)))
  key <- vapply(carried, paste, character(1), collapse = "|")
  groups <- split(axes, key)
  groups <- groups[lengths(groups) > 1L]
  if (!length(groups)) return(list())
  lapply(names(groups), function(k) {
    variables <- strsplit(k, "|", fixed = TRUE)[[1]]
    # The variable that separates the group is the one each axis holds at a
    # single value, not the one being read off it: in `sex (prior_uti=no)`
    # the axis is read on sex and chosen by prior_uti.
    constant <- Filter(function(p) all(vapply(groups[[k]], function(ax)
      length(unique(as.character(nom[[ax]][[p]]))) == 1L, logical(1))),
      variables)
    list(axes = groups[[k]], variables = variables,
         separated_by = constant,
         read_on = setdiff(variables, constant))
  })
}

#' The tabulated values each predictor has on the nomogram
#'
#' An axis may carry more than one variable. An interaction makes `rms` emit
#' mutually exclusive axes such as `sex (prior_uti=no)` and
#' `sex (prior_uti=yes)`, each holding both variables, so a predictor's ticks
#' have to be gathered across axes rather than read off one.
#'
#' @param nom An `rms` nomogram.
#' @param predictors Model predictors.
#' @return Named list of tabulated values.
#' @keywords internal
mm_axis_values <- function(nom, predictors) {
  axes <- mm_axis_names(nom)
  out <- lapply(predictors, function(p) {
    vals <- list()
    for (ax in axes) {
      el <- nom[[ax]]
      if (p %in% names(el)) vals[[length(vals) + 1L]] <- el[[p]]
    }
    if (!length(vals)) return(NULL)
    u <- unique(unlist(vals))
    if (is.numeric(u)) sort(u) else as.character(u)
  })
  names(out) <- predictors
  out[!vapply(out, is.null, logical(1))]
}

#' The predictor axes of a nomogram, excluding its scales
#' @param nom An `rms` nomogram.
#' @return Character vector of axis names.
#' @keywords internal
mm_axis_names <- function(nom) {
  keep <- !vapply(nom, function(el) {
    nm <- names(el)
    identical(nm, "x") || all(c("x", "x.real") %in% nm)
  }, logical(1))
  names(nom)[keep]
}

#' One profile per tabulated tick of every predictor
#'
#' Each predictor is varied over its ticks while the others sit at their
#' first, so every tick of every axis is exercised without taking the product
#' of them all.
#'
#' @param nom An `rms` nomogram.
#' @param model A [mm_model()].
#' @return A data frame of profiles.
#' @keywords internal
mm_tick_profiles <- function(nom, model) {
  vals <- mm_axis_values(nom, model$project$predictors)
  base <- lapply(vals, function(v) v[1])
  rows <- list()
  for (p in names(vals)) {
    for (tk in vals[[p]]) {
      row <- base
      row[[p]] <- tk
      rows[[length(rows) + 1L]] <- row
    }
  }
  frame <- do.call(rbind, lapply(rows, function(r)
    as.data.frame(r, stringsAsFactors = FALSE)))
  mm_restore_levels(frame, model$schema)
}

#' Give profile columns the factor levels the model was fitted with
#' @param frame A data frame of profiles.
#' @param schema A prediction schema.
#' @return The frame, with factors restored.
#' @keywords internal
mm_restore_levels <- function(frame, schema) {
  for (p in names(schema$predictors)) {
    spec <- schema$predictors[[p]]
    if (identical(spec$type, "categorical") && p %in% names(frame)) {
      frame[[p]] <- factor(as.character(frame[[p]]),
                           levels = spec$levels)
    }
  }
  frame
}

#' Convert total points to the linear predictor
#'
#' The printed linear predictor axis is affine in total points, so the line
#' through it is the exact mapping. Interpolating with clamped ends is not:
#' the axis need not be printed all the way down to zero points, and a
#' profile below its lowest tick would then be read as that tick. That is a
#' silent wrong answer, so the line is used and its linearity is checked
#' rather than trusted.
#'
#' @param nom An `rms` nomogram.
#' @param total Total points.
#' @return The linear predictor.
#' @keywords internal
mm_total_to_lp <- function(nom, total) {
  x <- nom$lp$x
  y <- nom$lp$x.real
  ok <- !is.na(x) & !is.na(y)
  x <- x[ok]; y <- y[ok]
  if (length(x) < 2L) return(NA_real_)
  slope <- (y[length(y)] - y[1]) / (x[length(x)] - x[1])
  intercept <- y[1] - slope * x[1]
  drift <- max(abs(y - (intercept + slope * x)))
  if (drift > 1e-8) {
    stop("the nomogram's linear predictor axis is not affine in total ",
         "points (worst deviation ", format(drift, digits = 3), "). The ",
         "points-to-risk reader assumes it is, so it cannot be trusted ",
         "here.", call. = FALSE)
  }
  intercept + slope * total
}

#' Whether a total falls outside the printed axis
#'
#' A reading off the end of the drawn axis is one a clinician cannot take,
#' however well the arithmetic behind it works.
#'
#' @param nom An `rms` nomogram.
#' @param total Total points.
#' @return `TRUE` when the total is off the printed scale.
#' @keywords internal
mm_off_axis <- function(nom, total) {
  rng <- range(nom$lp$x, na.rm = TRUE)
  total < rng[1] | total > rng[2]
}

#' Read one profile off the nomogram, as a clinician would
#'
#' Sums the points from each axis that applies to the profile, then
#' interpolates the total on the printed linear predictor axis. No model
#' object is consulted, which is what makes this a check rather than a
#' restatement of the fit.
#'
#' An axis applies only when the profile matches every categorical value the
#' axis holds fixed. That is how the mutually exclusive axes an interaction
#' produces are handled: exactly one of them applies, so no variable is
#' counted twice and none is missed.
#'
#' @param nom An `rms` nomogram.
#' @param profile One row.
#' @return Predicted risk, or `NA_real_` if no axis applies.
#' @keywords internal
mm_nomogram_risk <- function(nom, profile) {
  total <- mm_nomogram_points(nom, profile)
  stats::plogis(mm_total_to_lp(nom, total))
}

#' Total points for one profile
#' @param nom An `rms` nomogram.
#' @param profile One row.
#' @return Total points.
#' @keywords internal
mm_nomogram_points <- function(nom, profile) {
  total <- 0
  for (ax in mm_axis_names(nom)) {
    el <- nom[[ax]]
    vars <- intersect(setdiff(names(el), c("Xbeta", "points")),
                      names(profile))
    if (!length(vars)) next
    numeric_vars <- vars[vapply(vars, function(v) is.numeric(el[[v]]),
                                logical(1))]
    fixed_vars <- setdiff(vars, numeric_vars)
    keep <- rep(TRUE, length(el$points))
    for (v in fixed_vars) {
      keep <- keep & as.character(el[[v]]) == as.character(profile[[v]])
    }
    if (!any(keep)) next
    if (length(numeric_vars)) {
      v <- numeric_vars[1]
      xs <- el[[v]][keep]; ys <- el$points[keep]
      ok <- !is.na(xs) & !is.na(ys)
      total <- total + if (sum(ok) < 2L) ys[ok][1] else
        stats::approx(xs[ok], ys[ok], xout = as.numeric(profile[[v]]),
                      rule = 2)$y
    } else {
      total <- total + el$points[keep][1]
    }
  }
  total
}

#' The most an off-tick reading can differ from the model
#'
#' A bound, not a probe. The quantity is attained by some profile a clinician
#' could read, so it answers "how wrong can this nomogram be between its
#' printed ticks" rather than "how wrong was it at the places I happened to
#' look".
#'
#' @section Why a bound is computable without searching the joint space:
#'
#' Total points are additive across axes and the printed linear-predictor axis
#' is affine in them, so for any profile
#'
#' \deqn{lp_{nomogram} - lp_{model} = b \sum_j e_j(x_j)}
#'
#' where \eqn{e_j} is one axis's linear-interpolation error in points and
#' \eqn{b} is the points-to-lp slope. Each \eqn{e_j} is zero at that axis's
#' own ticks, which is what the tick-agreement check in [mm_nomogram()]
#' establishes, and each is free to take its own worst value because the
#' predictors are chosen independently. So the extremes of the sum are the
#' sums of the extremes, and one scan per axis is enough: no search over
#' combinations of predictors is needed, and none is done.
#'
#' Each axis is scanned with every other predictor sitting on a tick, so the
#' discrepancy observed is exactly that axis's. An axis is scanned once per
#' stratum it is drawn in, because an interaction with a factor gives a
#' continuous predictor a different points curve per level and `rms` draws
#' those as separate axes: on one fixture the `age` error ran to -0.046 in one
#' stratum where the other reached only -0.006, so a single stratum is not a
#' bound over both.
#'
#' The worst total error in points becomes a worst error in risk through the
#' logistic, whose steepest point is the one that matters:
#' \eqn{\max_u |plogis(u + \delta) - plogis(u)|} is attained at
#' \eqn{u = -\delta/2}, that is at a risk of one half. The bound does not ask
#' whether a profile with that risk also attains the worst points error, so it
#' holds whether or not one does.
#'
#' @section What it does not cover:
#'
#' Interpolation only. Not the clinician's eye on the printed page, not a total
#' falling off the drawn scale, which [mm_nomogram()] counts separately as
#' `off_axis`, and not a predictor outside the range the model was developed
#' on, which [mm_predict()] marks as `.extrapolated`. It is also a numerical
#' bound rather than an analytic one: each axis is scanned on a finite grid, so
#' a sharper extremum could sit between two scanned points. Measured, that
#' slack is about one part in a thousand: raising `per_gap` from 3 to 25 moved
#' the lp bound from 0.12613 to 0.12626 on a two-spline fixture whose worst
#' observed reading was 0.0215 against a bound of 0.0315. The slack runs an
#' order of magnitude smaller than the margin the bound already carries.
#'
#' @param nom An `rms` nomogram.
#' @param model A [mm_model()].
#' @param per_gap Interior points scanned in each gap between ticks. Cost is
#'   linear in it and in the number of axes, and the answer is stable well
#'   below the default.
#'
#' @return A list: `bound`, the largest absolute risk difference any reading
#'   between ticks can carry; `lp`, the same bound on the linear-predictor
#'   scale; and `by_axis`, each axis's own error range, which is where to look
#'   when the bound is too large and the question is which axis needs more
#'   ticks. `bound` and `lp` are `NA` when no axis has two ticks to read
#'   between, because then there is no off-tick reading to make.
#' @keywords internal
mm_reading_error <- function(nom, model, per_gap = 5L) {
  vals <- mm_axis_values(nom, model$project$predictors)
  continuous <- names(vals)[vapply(vals, is.numeric, logical(1)) &
                              lengths(vals) > 1L]
  if (!length(continuous)) {
    return(list(bound = NA_real_, lp = NA_real_, by_axis = NULL))
  }
  axes <- mm_axis_names(nom)
  base <- lapply(vals, function(v) v[1])

  reading_lp <- function(frame) {
    vapply(seq_len(nrow(frame)), function(i)
      mm_total_to_lp(nom, mm_nomogram_points(nom, frame[i, , drop = FALSE])),
      numeric(1))
  }

  by_axis <- t(vapply(continuous, function(v) {
    ticks <- vals[[v]]
    # Between the ticks and never on one, because the error is zero at a tick
    # and it is the gap that is being measured.
    interior <- unlist(lapply(seq_len(length(ticks) - 1L), function(k)
      seq(ticks[k], ticks[k + 1L],
          length.out = per_gap + 2L)[-c(1L, per_gap + 2L)]))
    worst <- c(lo = 0, hi = 0)
    for (ax in Filter(function(a) v %in% names(nom[[a]]), axes)) {
      el <- nom[[ax]]
      row <- base
      # The stratum this axis is drawn in. Each such axis holds its
      # categorical values at one level, which is what makes it a separate
      # axis in the first place.
      for (held in setdiff(names(el), c(v, "Xbeta", "points"))) {
        row[[held]] <- as.character(el[[held]][1])
      }
      frame <- as.data.frame(row, stringsAsFactors = FALSE)
      frame <- frame[rep(1L, length(interior)), , drop = FALSE]
      frame[[v]] <- interior
      frame <- mm_restore_levels(frame, model$schema)
      gap <- reading_lp(frame) -
        stats::qlogis(mm_predict(model, frame)$.pred)
      worst["lo"] <- min(worst["lo"], min(gap, na.rm = TRUE))
      worst["hi"] <- max(worst["hi"], max(gap, na.rm = TRUE))
    }
    worst
  }, numeric(2)))

  # The extremes of the sum are the sums of the extremes, each axis being
  # free to take its own worst value.
  delta <- max(abs(sum(by_axis[, "lo"])), abs(sum(by_axis[, "hi"])))
  list(bound = stats::plogis(delta / 2) - stats::plogis(-delta / 2),
       lp = delta, by_axis = by_axis)
}

#' Export the nomogram as vector and raster files
#' @param nom An `rms` nomogram.
#' @param out_dir Directory.
#' @param slug Study slug.
#' @param width,height Inches.
#' @return The paths written.
#' @keywords internal
mm_nomogram_export <- function(nom, out_dir, slug, width, height) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  stem <- file.path(out_dir, paste0(slug, "_nomogram"))
  draw <- function() {
    op <- graphics::par(mar = c(4, 2, 2, 2))
    on.exit(graphics::par(op), add = TRUE)
    graphics::plot(nom)
  }
  paths <- character(0)

  pdf_path <- paste0(stem, ".pdf")
  grDevices::pdf(pdf_path, width = width, height = height)
  draw(); grDevices::dev.off()
  paths <- c(paths, pdf_path)

  if (requireNamespace("svglite", quietly = TRUE)) {
    svg_path <- paste0(stem, ".svg")
    svglite::svglite(svg_path, width = width, height = height)
    draw(); grDevices::dev.off()
    paths <- c(paths, svg_path)
  }
  if (requireNamespace("ragg", quietly = TRUE)) {
    png_path <- paste0(stem, ".png")
    ragg::agg_png(png_path, width = width, height = height, units = "in",
                  res = 300)
    draw(); grDevices::dev.off()
    paths <- c(paths, png_path)
  }
  message("wrote ", length(paths), " nomogram file(s): ",
          paste(paths, collapse = ", "))
  paths
}

#' @export
print.mm_nomogram <- function(x, ...) {
  cat("<mm_nomogram>\n")
  cat("  axes            ", paste(x$axes, collapse = ", "), "\n", sep = "")
  cat("  profiles checked ", x$profiles_checked,
      " at tabulated ticks\n", sep = "")
  cat("  worst gap vs mm_predict() ",
      format(x$worst_disagreement, digits = 3), " (tolerance ",
      format(x$tolerance), ")\n", sep = "")
  if (x$off_axis > 0L) {
    cat("  off printed scale ", x$off_axis,
        " tick profile(s) fall beyond the drawn axis\n", sep = "")
  }
  cat("  between-tick reading      ",
      format(x$reading_error, digits = 3),
      " in risk at most, anywhere off the ticks\n", sep = "")
  if (!is.null(x$reading_error_by_axis) &&
      nrow(x$reading_error_by_axis) > 1L) {
    worst <- rownames(x$reading_error_by_axis)[
      which.max(apply(abs(x$reading_error_by_axis), 1, max))]
    cat("                            ", worst,
        " is the coarsest axis\n", sep = "")
  }
  if (length(x$exclusive_axes)) {
    cat("  mutually exclusive: exactly one axis of each group below applies\n")
    for (group in x$exclusive_axes) {
      cat("    ", paste(group$axes, collapse = "  |  "), "\n", sep = "")
      cat("      read on ", paste(group$read_on, collapse = ", "),
          ", chosen by ", paste(group$separated_by, collapse = ", "),
          "\n", sep = "")
    }
    cat("  axes        ", x$n_axes, " drawn for ", x$n_predictors,
        " predictor(s). Scoring two axes of one group double-counts the\n",
        "              patient, which no check here can see because it\n",
        "              happens on the printed sheet\n", sep = "")
  }
  if (length(x$files)) {
    cat("  files           ", paste(basename(x$files), collapse = ", "),
        "\n", sep = "")
  }
  invisible(x)
}
