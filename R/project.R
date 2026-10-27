#' Create a validated analysis configuration
#'
#' The analysis plan, written down and checked before anything is fitted. Every
#' later step reads this object, so no step has to guess and no two steps can
#' quietly disagree.
#'
#' Nothing is fitted and no row is modelled. `cp_project()` records choices and
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
#' @param seed Single whole number, recorded here so that a later resampling
#'   step cannot invent one of its own.
#'
#' @return An object of class `cp_project`.
#'
#' @examples
#' cp_project("uds", "event", c("age", "bmi", "sex"))
#'
#' # Temporal validation: develop before 2023, hold out 2023 onwards.
#' cp_project("uds", "event", c("age", "bmi"),
#'            split_var = "year", split_at = 2023)
#' @export
cp_project <- function(slug, outcome, predictors, positive_class = NULL,
                       cohort = NULL, split_var = NULL, split_at = NULL,
                       cluster_id = NULL, seed = 1978L) {
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
         seed           = as.integer(seed)),
    class = "cp_project"
  )
}

#' @export
print.cp_project <- function(x, ...) {
  cat("<cp_project: ", x$slug, ">\n", sep = "")
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
  cat("  seed       ", x$seed, "\n", sep = "")
  invisible(x)
}
