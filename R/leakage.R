#' Candidate 0/1 encodings of a column, where the meaning is unambiguous
#'
#' A predictor can only be an exact copy of a binary outcome if it carries the
#' same two-valued information, so this answers a narrow question: can this
#' column be read as 0/1 without guessing. Numeric columns holding only 0 and
#' 1, logicals, and any column with exactly two observed values qualify.
#' Everything else does not, which is what keeps an arbitrary string from
#' being coerced into an outcome.
#'
#' Two encodings are returned for a two-valued column, one per choice of which
#' value marks the event, because the labels are arbitrary and a comparison
#' that trusted them would miss a copy whose levels happen to read backwards.
#'
#' @param values A candidate predictor column.
#'
#' @return A list of encodings, each a list of `code` (0/1 integer with `NA`
#'   preserved) and `label` (how it was read). Empty when the column cannot be
#'   read as binary without guessing.
#' @keywords internal
mm_binary_forms <- function(values) {
  if (is.logical(values)) {
    return(list(list(code = as.integer(values), label = "TRUE is the event")))
  }
  seen <- unique(stats::na.omit(values))
  if (is.numeric(values)) {
    if (!length(seen) || !all(seen %in% c(0, 1))) return(list())
    return(list(list(code = as.integer(values),
                     label = "1 is the event")))
  }
  if (!is.factor(values) && !is.character(values)) return(list())
  seen <- sort(unique(stats::na.omit(as.character(values))))
  if (length(seen) != 2L) return(list())
  chr <- as.character(values)
  lapply(seen, function(event_value) {
    list(code = as.integer(chr == event_value),
         label = sprintf("\"%s\" is the event", event_value))
  })
}

#' Look for predictors that carry the outcome rather than predict it
#'
#' Three tiers, because they are three different findings and only one of them
#' is settled by arithmetic.
#'
#' **Tier 1, duplication.** A predictor that reproduces the outcome on every
#' eligible row, or its exact complement. There is no cohort in which that is
#' a prediction, so it is an error.
#'
#' **Tier 2, categorical separation.** Every observed level of a categorical
#' predictor falls in one outcome class. That can be leakage and can equally be
#' a small cohort, so it is reported for a human to settle.
#'
#' **Tier 3, numeric separation.** A threshold exists that separates the
#' classes completely. Same reasoning as tier 2.
#'
#' A strong but non-deterministic association is not reported at all. A
#' correlation is what a predictor is for.
#'
#' What this cannot do is worth stating, because the gap is where published
#' models go wrong: none of these tests says *when* a predictor was measured.
#' A variable recorded after the outcome, a treatment chosen because of it, or
#' a feature engineered from it can be weakly associated and still be leakage.
#' Checking availability at the moment of prediction is the analyst's, and no
#' comparison of columns can do it.
#'
#' @param project A [mm_project()].
#' @param frame The development rows, after eligibility. Not modified.
#' @param y Optional 0/1 outcome for those rows, to avoid recomputing it.
#' @param min_overlap Fewest rows with both values observed for a verdict of
#'   duplication. Below this an exact match carries too little information to
#'   separate a copy from a coincidence, so the predictor is left alone.
#'
#' @return A list of findings, each with `tier`, `predictor`, `kind`,
#'   `n_compared`, `n_missing` and `detail`.
#' @keywords internal
mm_leakage <- function(project, frame, y = NULL, min_overlap = 10L) {
  outcome <- project$outcome
  if (is.null(y)) {
    y <- mm_event_indicator(frame[[outcome]], project$positive_class)
  }
  findings <- list()
  note <- function(...) findings[[length(findings) + 1L]] <<- list(...)

  for (predictor in intersect(project$predictors, names(frame))) {
    values <- frame[[predictor]]
    both <- !is.na(y) & !is.na(values)
    n_compared <- sum(both)
    n_missing <- length(y) - n_compared
    if (!n_compared) next
    y_seen <- y[both]
    if (length(unique(y_seen)) < 2L) next
    enough <- n_compared >= min_overlap

    # Tier 1. Duplication, on the values and never on the names.
    duplicated_as <- NULL
    for (form in mm_binary_forms(values)) {
      code <- form$code[both]
      if (anyNA(code)) next
      if (all(code == y_seen)) {
        duplicated_as <- list(kind = "copy", label = form$label)
        break
      }
      if (all(code == 1L - y_seen)) {
        duplicated_as <- list(kind = "complement", label = form$label)
        break
      }
    }
    if (!is.null(duplicated_as) && enough) {
      note(tier = 1L, predictor = predictor,
           kind = duplicated_as$kind, n_compared = n_compared,
           n_missing = n_missing,
           detail = sprintf(
             paste("reads as binary with %s, and %s the outcome on every",
                   "one of the %d compared row(s)"),
             duplicated_as$label,
             if (identical(duplicated_as$kind, "copy")) "reproduces" else
               "is the exact complement of",
             n_compared))
      next
    }
    if (!is.null(duplicated_as)) {
      note(tier = 2L, predictor = predictor, kind = "too few to judge",
           n_compared = n_compared, n_missing = n_missing,
           detail = sprintf(paste("matches the outcome on all %d compared",
                                  "row(s), which is fewer than the %d needed",
                                  "to tell duplication from coincidence"),
                            n_compared, min_overlap))
      next
    }

    # Tier 2. Every observed level in one class. Observed, so an unused factor
    # level cannot manufacture the finding.
    if (is.factor(values) || is.character(values) || is.logical(values)) {
      levels_seen <- unique(as.character(values[both]))
      per_level <- vapply(levels_seen, function(level) {
        inside <- as.character(values[both]) == level
        length(unique(y_seen[inside]))
      }, integer(1))
      if (all(per_level == 1L)) {
        counts <- vapply(levels_seen, function(level)
          sum(as.character(values[both]) == level), integer(1))
        note(tier = 2L, predictor = predictor, kind = "separation",
             n_compared = n_compared, n_missing = n_missing,
             detail = sprintf(paste("every observed level falls in one",
                                    "outcome class: %s"),
                              paste(sprintf("%s (n = %d)", levels_seen,
                                            counts), collapse = ", ")))
      }
      next
    }

    # Tier 3. A threshold that separates completely.
    if (is.numeric(values)) {
      low <- values[both][y_seen == 0L]
      high <- values[both][y_seen == 1L]
      if (max(low) < min(high)) {
        note(tier = 3L, predictor = predictor, kind = "separation",
             n_compared = n_compared, n_missing = n_missing,
             detail = sprintf(paste("every event lies above every non-event:",
                                    "non-events reach %s, events start at %s"),
                              format(max(low)), format(min(high))))
      } else if (max(high) < min(low)) {
        note(tier = 3L, predictor = predictor, kind = "separation",
             n_compared = n_compared, n_missing = n_missing,
             detail = sprintf(paste("every event lies below every non-event:",
                                    "events reach %s, non-events start at %s"),
                              format(max(high)), format(min(low))))
      }
    }
  }
  findings
}

#' Raise what the leakage scan found, blocking only on duplication
#'
#' @param findings From [mm_leakage()].
#' @param outcome The outcome's name, for the message.
#' @return `invisible(findings)`, after erroring on any tier 1 finding and
#'   warning on the rest.
#' @keywords internal
mm_report_leakage <- function(findings, outcome) {
  if (!length(findings)) return(invisible(findings))
  tiers <- vapply(findings, function(finding) finding$tier, integer(1))

  blocking <- findings[tiers == 1L]
  if (length(blocking)) {
    stop("outcome leakage: ",
         paste(vapply(blocking, function(finding) sprintf(
           "predictor `%s` %s", finding$predictor, finding$detail),
           character(1)), collapse = "; "),
         ". A predictor carrying `", outcome, "` is not predicting it, and a ",
         "model given one reports near-perfect discrimination, which reads ",
         "as success. Remove it before fitting.", call. = FALSE)
  }

  warning("possible outcome leakage, reported rather than refused because ",
          "perfect separation can be a small cohort rather than a mistake: ",
          paste(vapply(findings, function(finding) sprintf(
            "predictor `%s` %s, over %d compared row(s)",
            finding$predictor, finding$detail, finding$n_compared),
            character(1)), collapse = "; "),
          ". Check when each was measured relative to `", outcome,
          "`, which no comparison of columns can tell you.", call. = FALSE)
  invisible(findings)
}
