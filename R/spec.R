#' Specify a prediction model before fitting one
#'
#' The object every other step reads. It records what is being predicted, from
#' which columns, and how the data divides into development and held-out, so no
#' later step has to guess and no two steps can quietly disagree.
#'
#' Nothing is fitted and no row is read. `mm_spec()` records choices and refuses
#' incoherent ones. That is the point: the specification is what a reviewer
#' should be able to read and check before a model exists, which is the opposite
#' of recovering it afterwards from the code that happened to run.
#'
#' @param outcome Length-one character naming the outcome column.
#' @param predictors Character vector of candidate predictor columns. The order
#'   is kept, because it is the order a report presents them in.
#' @param data Optional data frame. When given, every name in `outcome`,
#'   `predictors` and `split_var` must be one of its columns, and the error
#'   names the ones that are not. The data itself is not stored.
#' @param split_var Optional length-one character naming the column that
#'   separates development from held-out data, most often a year.
#' @param split_at Optional single value. Rows with `split_var < split_at` are
#'   development and the rest are held out. Goes with `split_var`.
#' @param seed Single whole number, recorded here so that a later resampling
#'   step cannot invent one of its own.
#'
#' @return An object of class `mysterymodel_spec`: a list with components
#'   `outcome`, `predictors`, `split_var`, `split_at` and `seed`.
#'
#' @examples
#' mm_spec("matched", c("step_1_score", "research_count", "sex"))
#'
#' # Temporal validation: develop before 2023, hold out 2023 onwards.
#' mm_spec("matched", c("step_1_score", "research_count"),
#'         split_var = "app_year", split_at = 2023)
#' @export
mm_spec <- function(outcome, predictors, data = NULL,
                    split_var = NULL, split_at = NULL, seed = 1978L) {
  if (!is.character(outcome) || length(outcome) != 1L ||
      is.na(outcome) || !nzchar(outcome)) {
    stop("`outcome` must be a single non-empty column name.", call. = FALSE)
  }
  if (!is.character(predictors) || !length(predictors) ||
      anyNA(predictors) || !all(nzchar(predictors))) {
    stop("`predictors` must be a non-empty character vector of column names.",
         call. = FALSE)
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
    stop("`split_var` and `split_at` go together. One without the other does ",
         "not describe a split.", call. = FALSE)
  }
  if (!is.null(split_var)) {
    if (!is.character(split_var) || length(split_var) != 1L ||
        is.na(split_var) || !nzchar(split_var)) {
      stop("`split_var` must be a single non-empty column name.",
           call. = FALSE)
    }
    if (length(split_at) != 1L || is.na(split_at)) {
      stop("`split_at` must be a single non-missing value.", call. = FALSE)
    }
  }

  if (length(seed) != 1L || is.na(seed) || !is.numeric(seed) ||
      seed != trunc(seed)) {
    stop("`seed` must be a single whole number.", call. = FALSE)
  }

  if (!is.null(data)) {
    if (!is.data.frame(data)) {
      stop("`data` must be a data frame.", call. = FALSE)
    }
    absent <- setdiff(c(outcome, predictors, split_var), names(data))
    if (length(absent)) {
      stop("not columns of `data`: ", paste(absent, collapse = ", "),
           call. = FALSE)
    }
  }

  structure(
    list(outcome    = outcome,
         predictors = predictors,
         split_var  = split_var,
         split_at   = split_at,
         seed       = as.integer(seed)),
    class = "mysterymodel_spec"
  )
}

#' @export
print.mysterymodel_spec <- function(x, ...) {
  cat("<mysterymodel spec>\n")
  cat("  outcome    ", x$outcome, "\n", sep = "")
  cat("  predictors ", length(x$predictors), ": ",
      paste(x$predictors, collapse = ", "), "\n", sep = "")
  if (is.null(x$split_var)) {
    cat("  split      none\n")
  } else {
    cat("  split      ", x$split_var, " < ", format(x$split_at),
        " develops, the rest is held out\n", sep = "")
  }
  cat("  seed       ", x$seed, "\n", sep = "")
  invisible(x)
}
