#' Create a validated analysis configuration
#'
#' The analysis plan, written down and checked before anything is fitted. Every
#' later step reads this object, so no step has to guess and no two steps can
#' quietly disagree.
#'
#' Nothing is fitted and no row is modelled. `mm_project()` records choices and
#' fails closed on combinations that cannot be meant. That is the point: the
#' configuration is what a reviewer should be able to check against the
#' protocol, rather than reconstruct afterwards from whichever code ran.
#'
#' @param slug Short study identifier, used in artifact paths.
#' @param outcome Length-one character naming the outcome column.
#' @param predictors Character vector of candidate predictor columns. The
#'   order is kept, because it is the order a report presents them in.
#' @param positive_class Optional value naming the event level of `outcome`.
#'   Checked against the observed values when `cohort` is supplied, because
#'   an inverted positive class silently inverts every reported risk.
#' @param cohort Optional data frame. When supplied, every column named here
#'   must exist in it, the outcome must vary, and `positive_class` must be one
#'   of the outcome's observed values. The cohort itself is not stored.
#' @param split_var Optional length-one character naming the column that
#'   separates development from held-out data, most often a year.
#' @param split_at Optional single value. Rows with `split_var < split_at` are
#'   development and the rest are held out.
#' @param cluster_id Optional length-one character naming the column that
#'   identifies repeated observations on one patient, for clustered
#'   resampling.
#' @param nonlinear Optional character vector of continuous predictors to fit
#'   with restricted cubic splines. Part of the plan rather than of the
#'   fitting call, because how many degrees of freedom a continuous predictor
#'   is given is a prespecified choice: section 78 of the specification asks
#'   the configuration to carry the spline and interaction terms, and a plan
#'   that lives in whichever `mm_model()` call ran is not one a reviewer can
#'   check against a protocol. Left `NULL` the project records no shape, which
#'   is not the same as recording that every continuous predictor is straight:
#'   [mm_model()] then takes its own argument without calling it a departure,
#'   because there is no plan to depart from. [mm_splines()] shows what the
#'   choice is worth before it is written down.
#' @param interactions Optional list of length-two character vectors naming
#'   prespecified interaction blocks. Exploratory discovery is not this
#'   argument; [mm_interactions()] reports evidence and selects nothing.
#' @param knots Knots for each spline term.
#' @param seed Single whole number, recorded here so that a later resampling
#'   step cannot invent one of its own.
#'
#' @return An object of class `mm_project`.
#'
#' @examples
#' mm_project("uds", "event", c("age", "bmi", "sex"))
#'
#' # Temporal validation: develop before 2023, hold out 2023 onwards.
#' mm_project("uds", "event", c("age", "bmi"),
#'            split_var = "year", split_at = 2023)
#' @export
mm_project <- function(slug, outcome, predictors, positive_class = NULL,
                       cohort = NULL, split_var = NULL, split_at = NULL,
                       cluster_id = NULL, nonlinear = NULL,
                       interactions = NULL, knots = 4L, seed = 1978L) {
  one_name <- function(x, what) {
    if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
      stop("`", what, "` must be a single non-empty name.", call. = FALSE)
    }
  }
  one_name(slug, "slug")
  one_name(outcome, "outcome")

  if (!is.character(predictors) || !length(predictors) ||
      anyNA(predictors) || !all(nzchar(predictors))) {
    stop("`predictors` must be a non-empty character vector of column ",
         "names.", call. = FALSE)
  }
  repeated <- unique(predictors[duplicated(predictors)])
  if (length(repeated)) {
    stop("`predictors` repeats ", paste(repeated, collapse = ", "),
         ". A predictor listed twice is entered twice.", call. = FALSE)
  }
  if (outcome %in% predictors) {
    stop("`outcome` (", outcome, ") is also in `predictors`. A model given ",
         "its own outcome reports perfect discrimination.", call. = FALSE)
  }

  if (is.null(split_var) != is.null(split_at)) {
    stop("`split_var` and `split_at` go together. Temporal validation ",
         "without a time field does not describe a split.", call. = FALSE)
  }
  if (!is.null(split_var)) {
    one_name(split_var, "split_var")
    if (length(split_at) != 1L || is.na(split_at)) {
      stop("`split_at` must be a single non-missing value.", call. = FALSE)
    }
  }
  if (!is.null(cluster_id)) one_name(cluster_id, "cluster_id")

  if (!is.null(nonlinear)) {
    if (!is.character(nonlinear) || anyNA(nonlinear) ||
        !all(nzchar(nonlinear))) {
      stop("`nonlinear` must be a character vector of predictor names.",
           call. = FALSE)
    }
    off <- setdiff(nonlinear, predictors)
    if (length(off)) {
      stop("`nonlinear` names terms that are not predictors: ",
           paste(off, collapse = ", "), call. = FALSE)
    }
    repeated_spline <- unique(nonlinear[duplicated(nonlinear)])
    if (length(repeated_spline)) {
      stop("`nonlinear` repeats ", paste(repeated_spline, collapse = ", "),
           ". A predictor is given one spline or none.", call. = FALSE)
    }
  }
  if (length(knots) != 1L || !is.numeric(knots) || is.na(knots) ||
      knots != trunc(knots) || knots < 3L) {
    stop("`knots` must be a single whole number of at least 3. A restricted ",
         "cubic spline needs three knots before it can bend.", call. = FALSE)
  }
  if (!is.null(interactions)) {
    # The same checks mm_model() applies when it builds a formula, run here so
    # a plan that cannot be meant fails when it is written down rather than
    # when something is fitted from it.
    if (!is.list(interactions)) {
      stop("`interactions` must be a list of length-two character vectors.",
           call. = FALSE)
    }
    asked <- character(0)
    for (block in interactions) {
      if (!is.character(block) || length(block) != 2L || anyNA(block) ||
          !all(nzchar(block))) {
        stop("each interaction must name exactly two predictors.",
             call. = FALSE)
      }
      if (identical(block[1], block[2])) {
        stop("interaction ", block[1], ":", block[2], " crosses a predictor ",
             "with itself, which a formula reduces to the main effect. ",
             "Curvature belongs in `nonlinear`.", call. = FALSE)
      }
      if (outcome %in% block) {
        stop("interaction ", paste(block, collapse = ":"), " contains the ",
             "outcome. An interaction with the outcome is not a predictor.",
             call. = FALSE)
      }
      missing_main <- setdiff(block, predictors)
      if (length(missing_main)) {
        stop("interaction ", paste(block, collapse = ":"), " needs its main ",
             "effect(s) ", paste(missing_main, collapse = ", "),
             " among the predictors. An interaction without its main ",
             "effects is not interpretable.", call. = FALSE)
      }
      key <- paste(sort(block), collapse = ":")
      if (key %in% asked) {
        stop("interaction ", key, " is listed more than once. Reversing a ",
             "pair does not make a different interaction.", call. = FALSE)
      }
      asked <- c(asked, key)
    }
  }

  if (length(seed) != 1L || is.na(seed) || !is.numeric(seed) ||
      seed != trunc(seed)) {
    stop("`seed` must be a single whole number.", call. = FALSE)
  }

  if (!is.null(cohort)) {
    if (!is.data.frame(cohort)) {
      stop("`cohort` must be a data frame.", call. = FALSE)
    }
    wanted <- c(outcome, predictors, split_var, cluster_id)
    absent <- setdiff(wanted, names(cohort))
    if (length(absent)) {
      stop("not columns of `cohort`: ", paste(absent, collapse = ", "),
           call. = FALSE)
    }
    seen <- unique(stats::na.omit(cohort[[outcome]]))
    if (length(seen) < 2L) {
      stop("`", outcome, "` takes ", length(seen), " distinct non-missing ",
           "value(s) in `cohort`. An outcome that does not vary cannot be ",
           "modelled.", call. = FALSE)
    }
    if (!is.null(positive_class) &&
        !positive_class %in% as.character(seen)) {
      stop("`positive_class` (", positive_class, ") is not an observed ",
           "value of `", outcome, "`. Observed: ",
           paste(sort(as.character(seen)), collapse = ", "),
           ". An inverted positive class inverts every reported risk.",
           call. = FALSE)
    }
  }

  structure(
    list(slug           = slug,
         outcome        = outcome,
         predictors     = predictors,
         positive_class = positive_class,
         split_var      = split_var,
         split_at       = split_at,
         cluster_id     = cluster_id,
         nonlinear      = nonlinear,
         interactions   = interactions,
         knots          = as.integer(knots),
         seed           = as.integer(seed)),
    class = "mm_project"
  )
}

#' @export
print.mm_project <- function(x, ...) {
  cat("<mm_project: ", x$slug, ">\n", sep = "")
  cat("  outcome    ", x$outcome,
      if (is.null(x$positive_class)) "" else
        paste0(" (event = ", x$positive_class, ")"), "\n", sep = "")
  cat("  predictors ", length(x$predictors), ": ",
      paste(x$predictors, collapse = ", "), "\n", sep = "")
  if (is.null(x$split_var)) {
    cat("  split      none\n")
  } else {
    cat("  split      ", x$split_var, " < ", format(x$split_at),
        " develops, the rest is held out\n", sep = "")
  }
  if (!is.null(x$cluster_id)) {
    cat("  cluster    ", x$cluster_id, "\n", sep = "")
  }
  cat("  shape      ",
      if (is.null(x$nonlinear)) "every continuous predictor linear" else
        paste0("spline on ", paste(x$nonlinear, collapse = ", "), ", ",
               x$knots, " knots"),
      "\n", sep = "")
  if (!is.null(x$interactions)) {
    cat("  blocks     ",
        paste(vapply(x$interactions, paste, character(1), collapse = ":"),
              collapse = ", "), "\n", sep = "")
  }
  cat("  seed       ", x$seed, "\n", sep = "")
  invisible(x)
}
