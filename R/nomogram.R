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
#' reading it, not a defect here, and `reading_error` reports its size instead
#' of hiding it.
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

  files <- character(0)
  if (!is.null(out_dir)) {
    files <- mm_nomogram_export(nom, out_dir, model$project$slug,
                               width, height)
  }

  structure(list(nomogram = nom, axes = axes,
                 profiles_checked = nrow(profiles),
                 worst_disagreement = worst, tolerance = tolerance,
                 off_axis = sum(mm_off_axis(nom, totals)),
                 reading_error = mm_reading_error(nom, model),
                 files = files, fingerprint = model$fingerprint),
            class = "mm_nomogram")
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
  mm_profiles(mm_axis_values(nom, model$project$predictors), identity,
              model$schema)
}

#' One profile per selected value of every predictor
#'
#' One predictor moves at a time while the others sit at their first tabulated
#' value, so every value `pick` selects is exercised without taking the product
#' of them all. Both callers build this shape and differ only in which values
#' they visit, which is why the construction is here: the on-tick agreement
#' and the between-tick reading error are compared with each other, and that
#' comparison assumes one shape.
#'
#' @param vals Tabulated values per predictor, from [mm_axis_values()].
#' @param pick Given one predictor's values, the values to visit. Length zero
#'   skips that predictor.
#' @param schema The model's prediction schema, whose factor levels the
#'   profiles are given back before they are returned.
#' @return A data frame of profiles, or `NULL` when `pick` selected nothing.
#' @keywords internal
mm_profiles <- function(vals, pick, schema) {
  base <- lapply(vals, function(v) v[1])
  rows <- list()
  for (p in names(vals)) {
    for (at in pick(vals[[p]])) {
      row <- base
      row[[p]] <- at
      rows[[length(rows) + 1L]] <- row
    }
  }
  if (!length(rows)) return(NULL)
  mm_restore_levels(
    do.call(rbind, lapply(rows, function(r)
      as.data.frame(r, stringsAsFactors = FALSE))), schema)
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

#' How far an off-tick reading can be from the model
#'
#' Reported so the axis's own resolution is a stated number rather than an
#' unexamined assumption. Evaluated midway between ticks, the worst case for
#' linear interpolation across a curve.
#'
#' @param nom An `rms` nomogram.
#' @param model A [mm_model()].
#' @return Largest absolute risk difference found between ticks.
#' @keywords internal
mm_reading_error <- function(nom, model) {
  # A categorical axis has no midpoint, so `pick` selects nothing for one and
  # it contributes no profile.
  frame <- mm_profiles(
    mm_axis_values(nom, model$project$predictors),
    function(v) {
      if (!is.numeric(v) || length(v) < 2L) return(numeric(0))
      (utils::head(v, -1) + utils::tail(v, -1)) / 2
    },
    model$schema)
  if (is.null(frame)) return(NA_real_)
  read <- vapply(seq_len(nrow(frame)),
                 function(i) mm_nomogram_risk(nom, frame[i, , drop = FALSE]),
                 numeric(1))
  max(abs(read - mm_predict(model, frame)$.pred), na.rm = TRUE)
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
  cat("  off-tick reading error    ",
      format(x$reading_error, digits = 3),
      " in risk, midway between ticks\n", sep = "")
  if (length(x$files)) {
    cat("  files           ", paste(basename(x$files), collapse = ", "),
        "\n", sep = "")
  }
  invisible(x)
}
