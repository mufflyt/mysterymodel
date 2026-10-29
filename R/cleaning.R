#' Apply eligibility rules and account for every row that leaves
#'
#' Each rule is a named one-sided formula evaluated in the cohort. Rows where
#' it is `TRUE` continue; rows where it is `FALSE` are excluded and attributed
#' to that rule by name.
#'
#' The ledger is the point. A cohort count that cannot be reconciled against
#' the raw export is the commonest reason a published flow diagram does not
#' add up, so this function refuses to return one: rows in must equal rows out
#' plus every exclusion, and the check is an error rather than a note.
#'
#' A rule that evaluates to `NA` for a row is not a pass. A row whose
#' eligibility cannot be determined is excluded under its own heading, because
#' treating unknown as eligible and treating it as ineligible are different
#' studies and the difference belongs in the diagram.
#'
#' Nothing here imputes, recodes or drops a column. Missingness is described
#' by [cp_eda()] and handled at imputation, where the choice is explicit.
#'
#' @param cohort The raw cohort.
#' @param rules Named list of one-sided formulas, each evaluating to a
#'   logical vector over `cohort`, as `~ age >= 40`. A formula is used rather
#'   than a bare expression so that nothing is evaluated before the cohort is
#'   in scope. The names become the ledger's labels, so they should read as
#'   the criterion they express.
#' @param label What the rows are, for the ledger's opening line.
#'
#' @return An object of class `cp_cohort`, holding `data` and `ledger`.
#'
#' @examples
#' raw <- cp_synthetic_cohort(n = 300, seed = 1)
#' clean <- cp_clean(raw, rules = list(
#'   "aged 40 or over" = ~ age >= 40,
#'   "plausible BMI"   = ~ bmi >= 16 & bmi <= 55
#' ))
#' clean
#' clean$ledger
#' @export
cp_clean <- function(cohort, rules = list(), label = "rows as supplied") {
  if (!is.data.frame(cohort)) {
    stop("`cohort` must be a data frame.", call. = FALSE)
  }
  if (!is.list(rules)) {
    stop("`rules` must be a list of one-sided formulas.", call. = FALSE)
  }
  if (length(rules)) {
    if (is.null(names(rules)) || !all(nzchar(names(rules)))) {
      stop("every rule needs a name, because the name is what the flow ",
           "diagram will say.", call. = FALSE)
    }
    not_formula <- !vapply(rules, inherits, logical(1), "formula")
    if (any(not_formula)) {
      stop("rule(s) ", paste(names(rules)[not_formula], collapse = ", "),
           " are not formulas. Write a rule as ~ age >= 40, so that it is ",
           "not evaluated before the cohort is in scope.", call. = FALSE)
    }
    two_sided <- vapply(rules, function(f) length(f) != 2L, logical(1))
    if (any(two_sided)) {
      stop("rule(s) ", paste(names(rules)[two_sided], collapse = ", "),
           " have a left-hand side. A rule is one-sided: ~ age >= 40.",
           call. = FALSE)
    }
  }

  n_in <- nrow(cohort)
  keep <- rep(TRUE, n_in)
  ledger <- list(data.frame(
    step = 0L, rule = label, n_before = NA_integer_,
    n_excluded = NA_integer_, n_after = n_in,
    reason = "starting cohort", stringsAsFactors = FALSE))

  note <- function(step, rule, before, excluded, reason) {
    data.frame(step = step, rule = rule, n_before = before,
               n_excluded = excluded, n_after = sum(keep),
               reason = reason, stringsAsFactors = FALSE)
  }

  for (i in seq_along(rules)) {
    nm <- names(rules)[i]
    before <- sum(keep)

    verdict <- tryCatch(
      eval(rules[[i]][[2L]], envir = cohort,
           enclos = environment(rules[[i]])),
      error = function(e) {
        stop("rule \"", nm, "\" could not be evaluated: ",
             conditionMessage(e), call. = FALSE)
      })
    if (!is.logical(verdict) || length(verdict) != n_in) {
      stop("rule \"", nm, "\" must give one TRUE or FALSE per row of the ",
           "cohort, and gave ", length(verdict), " ", class(verdict)[1],
           " value(s) for ", n_in, " row(s).", call. = FALSE)
    }

    undecided <- keep & is.na(verdict)
    failed <- keep & !is.na(verdict) & !verdict

    if (any(failed)) {
      keep <- keep & !failed
      ledger[[length(ledger) + 1L]] <- note(
        i, nm, before, sum(failed), "did not meet the criterion")
    }
    if (any(undecided)) {
      before2 <- sum(keep)
      keep <- keep & !undecided
      ledger[[length(ledger) + 1L]] <- note(
        i, nm, before2, sum(undecided),
        "criterion could not be determined for these rows")
    }
  }

  out <- cohort[keep, , drop = FALSE]
  row.names(out) <- NULL
  frame <- do.call(rbind, ledger)
  excluded <- sum(frame$n_excluded, na.rm = TRUE)

  if (n_in - excluded != nrow(out)) {
    stop("the ledger does not reconcile: ", n_in, " in, ", excluded,
         " excluded, ", nrow(out), " out. A row has left without a reason, ",
         "which is the one thing this function exists to prevent.",
         call. = FALSE)
  }

  structure(list(data = out, ledger = frame, n_in = n_in,
                 n_out = nrow(out), n_excluded = excluded),
            class = "cp_cohort")
}

#' @export
print.cp_cohort <- function(x, ...) {
  cat("<cp_cohort>  ", x$n_in, " in, ", x$n_out, " out, ",
      x$n_excluded, " excluded\n", sep = "")
  for (i in seq_len(nrow(x$ledger))) {
    row <- x$ledger[i, ]
    if (is.na(row$n_excluded)) {
      cat("  ", format(row$n_after, width = 6), "  ", row$rule, "\n",
          sep = "")
    } else {
      cat("  ", format(-row$n_excluded, width = 6), "  ", row$rule,
          " (", row$reason, ")\n", sep = "")
      cat("  ", format(row$n_after, width = 6), "  remaining\n", sep = "")
    }
  }
  invisible(x)
}
