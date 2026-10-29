#' Describe the cohort, with denominators and missingness
#'
#' A Table 1 in tidy form: one row per variable level or statistic, overall
#' and by outcome, with the denominator each percentage is taken over and the
#' missing count beside it.
#'
#' Missingness travels with the description rather than in a separate table,
#' because a percentage whose denominator excludes missing rows reads as a
#' fact about the cohort when it is a fact about the rows that happened to be
#' complete.
#'
#' Formatting follows the specification: counts with thousands separators,
#' percentages to one decimal, means with standard deviations, medians with
#' the quartiles.
#'
#' No dependency on a table-rendering package. This returns a data frame, so
#' `gt`, `gtsummary`, `knitr::kable()` or Quarto can render it, and none of
#' them is needed to compute it.
#'
#' @param cohort A data frame, or a [cp_clean()] result.
#' @param by Optional column to stratify by, typically the outcome.
#' @param vars Columns to describe. Defaults to all but `by`.
#' @param digits Decimal places for continuous summaries.
#'
#' @return An object of class `cp_eda`, holding `table` and `missing`.
#'
#' @examples
#' cohort <- cp_synthetic_cohort(n = 300, seed = 1)
#' cp_eda(cohort, by = "event", vars = c("age", "bmi", "sex"))
#' @export
cp_eda <- function(cohort, by = NULL, vars = NULL, digits = 1) {
  if (inherits(cohort, "cp_cohort")) cohort <- cohort$data
  if (!is.data.frame(cohort)) {
    stop("`cohort` must be a data frame or a cp_clean() result.",
         call. = FALSE)
  }
  if (!is.null(by)) {
    if (length(by) != 1L || !by %in% names(cohort)) {
      stop("`by` must name one column of the cohort.", call. = FALSE)
    }
  }
  vars <- vars %||% setdiff(names(cohort), by)
  absent <- setdiff(vars, names(cohort))
  if (length(absent)) {
    stop("not columns of the cohort: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }

  strata <- if (is.null(by)) list(Overall = seq_len(nrow(cohort))) else {
    lev <- sort(unique(as.character(stats::na.omit(cohort[[by]]))))
    out <- c(list(Overall = seq_len(nrow(cohort))),
             lapply(lev, function(l)
               which(as.character(cohort[[by]]) == l)))
    names(out) <- c("Overall", paste0(by, " = ", lev))
    out
  }

  rows <- list()
  add <- function(variable, statistic, values) {
    rows[[length(rows) + 1L]] <<- data.frame(
      c(list(variable = variable, statistic = statistic), values),
      stringsAsFactors = FALSE, check.names = FALSE)
  }

  for (v in vars) {
    col <- cohort[[v]]
    n_missing <- sum(is.na(col))

    if (is.numeric(col)) {
      add(v, "mean (SD)", lapply(strata, function(ix)
        cp_mean_sd(col[ix], digits)))
      add(v, "median (p25, p75)", lapply(strata, function(ix)
        cp_median_iqr(col[ix], digits)))
    } else {
      lev <- levels(factor(col))
      for (l in lev) {
        add(v, paste0(l, ", n (%)"), lapply(strata, function(ix) {
          sub <- col[ix]
          denom <- sum(!is.na(sub))
          cp_n_pct(sum(!is.na(sub) & as.character(sub) == l), denom)
        }))
      }
    }
    add(v, "missing, n (%)", lapply(strata, function(ix)
      cp_n_pct(sum(is.na(col[ix])), length(ix))))
  }

  table <- do.call(rbind, rows)
  denom <- data.frame(
    c(list(variable = "(denominator)", statistic = "n"),
      lapply(strata, function(ix) cp_count(length(ix)))),
    stringsAsFactors = FALSE, check.names = FALSE)
  table <- rbind(denom, table)

  missing <- data.frame(
    variable = vars,
    n_missing = vapply(vars, function(v) sum(is.na(cohort[[v]])),
                       integer(1)),
    pct_missing = vapply(vars, function(v)
      round(100 * mean(is.na(cohort[[v]])), 1), numeric(1)),
    row.names = NULL, stringsAsFactors = FALSE)
  missing <- missing[order(-missing$pct_missing), ]

  structure(list(table = table, missing = missing, n = nrow(cohort),
                 by = by,
                 duplicates = sum(duplicated(cohort))),
            class = "cp_eda")
}

#' Count with thousands separators
#' @param n A count.
#' @return A string.
#' @keywords internal
cp_count <- function(n) formatC(n, format = "d", big.mark = ",")

#' Count and percentage of a stated denominator
#' @param n Count.
#' @param denom Denominator.
#' @return A string.
#' @keywords internal
cp_n_pct <- function(n, denom) {
  if (denom == 0L) return("0 (-)")
  sprintf("%s (%.1f%%)", cp_count(n), 100 * n / denom)
}

#' Mean and standard deviation
#' @param x Values.
#' @param digits Decimal places.
#' @return A string.
#' @keywords internal
cp_mean_sd <- function(x, digits = 1) {
  x <- x[!is.na(x)]
  if (!length(x)) return("-")
  sprintf("%.*f (%.*f)", digits, mean(x), digits, stats::sd(x))
}

#' Median with quartiles
#' @param x Values.
#' @param digits Decimal places.
#' @return A string.
#' @keywords internal
cp_median_iqr <- function(x, digits = 1) {
  x <- x[!is.na(x)]
  if (!length(x)) return("-")
  q <- stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE)
  sprintf("%.*f (%.*f, %.*f)", digits, q[2], digits, q[1], digits, q[3])
}

#' @export
print.cp_eda <- function(x, ...) {
  cat("<cp_eda>  ", cp_count(x$n), " rows", sep = "")
  if (!is.null(x$by)) cat(", by ", x$by, sep = "")
  if (x$duplicates > 0L) {
    cat(", ", cp_count(x$duplicates), " duplicated row(s)", sep = "")
  }
  cat("\n")
  print(x$table, row.names = FALSE)
  worst <- x$missing[x$missing$n_missing > 0L, , drop = FALSE]
  if (nrow(worst)) {
    cat("\nmissing: ")
    cat(paste(sprintf("%s %.1f%%", worst$variable, worst$pct_missing),
              collapse = ", "), "\n")
  }
  invisible(x)
}
