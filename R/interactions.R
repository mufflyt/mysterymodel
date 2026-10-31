#' Candidate interaction pairs, checked before anything is fitted
#'
#' Strong hierarchy is checked by [mm_model()] when it builds a formula. This
#' checks the things a formula cannot: that a pair is a pair, that it is not a
#' predictor with itself, and that the same block has not been asked for twice
#' under two spellings. An interaction's identity is the unordered pair, so
#' `c("age", "sex")` and `c("sex", "age")` are the same candidate.
#'
#' @param project A [mm_project()].
#' @param candidates List of length-two character vectors.
#' @return The candidates, each with a `label` and the unordered `key` used to
#'   compare them.
#' @keywords internal
mm_candidate_pairs <- function(project, candidates) {
  if (!is.list(candidates) || !length(candidates)) {
    stop("`candidates` must be a non-empty list of length-two character ",
         "vectors naming the interactions to evaluate.", call. = FALSE)
  }
  seen <- character(0)
  lapply(seq_along(candidates), function(i) {
    pair <- candidates[[i]]
    if (!is.character(pair) || length(pair) != 2L || anyNA(pair) ||
        !all(nzchar(pair))) {
      stop("candidate ", i, " must be two non-empty predictor names.",
           call. = FALSE)
    }
    if (identical(pair[1], pair[2])) {
      stop("candidate ", i, " is `", pair[1], "` with itself. A predictor ",
           "crossed with itself adds no term: a formula reduces it to the ",
           "main effect, so the block would be tested on zero degrees of ",
           "freedom. Curvature is `nonlinear`, not an interaction.",
           call. = FALSE)
    }
    if (project$outcome %in% pair) {
      stop("candidate ", i, " contains the outcome `", project$outcome,
           "`. An interaction with the outcome is not a predictor.",
           call. = FALSE)
    }
    absent <- setdiff(pair, project$predictors)
    if (length(absent)) {
      stop("candidate ", i, " names ", paste(absent, collapse = ", "),
           ", which the project does not declare as a predictor. An ",
           "interaction is only usable with its main effects.", call. = FALSE)
    }
    key <- paste(sort(pair), collapse = ":")
    if (key %in% seen) {
      stop("candidate ", i, " repeats the block ", key,
           ", which an earlier candidate already asks for. Reversing a pair ",
           "does not make a different interaction.", call. = FALSE)
    }
    seen <<- c(seen, key)
    list(pair = pair, label = paste(pair, collapse = " x "), key = key)
  })
}

#' The rank of a design matrix, scaled so units cannot decide it
#'
#' From the singular values with a relative tolerance, rather than from
#' `qr()`, because a column measured in years and one in kilograms differ by
#' orders of magnitude and the pivoted decomposition's default tolerance then
#' answers a question about scaling rather than about rank.
#'
#' @param x A design matrix.
#' @param tol Relative tolerance on the singular values.
#' @return The rank.
#' @keywords internal
mm_matrix_rank <- function(x, tol = 1e-7) {
  if (is.null(x) || !ncol(x) || !nrow(x)) return(0L)
  varying <- apply(x, 2, function(col) stats::sd(col) > 0)
  if (!any(varying)) return(0L)
  singular <- svd(scale(x[, varying, drop = FALSE]))$d
  sum(singular > tol * max(singular))
}

#' Whether a candidate interaction is identifiable at all
#'
#' The required invariant, computed before any model is fitted and without
#' needing one to converge. The aliased case is exactly the case that kills
#' [rms::lrm()] with a singular Hessian, so a check that read the design
#' matrix off a fitted object could never run on the candidate that most needs
#' it.
#'
#' Three outcomes are distinguished, because they are three different facts:
#'
#' * the interaction adds columns and the same number of dimensions, so it is
#'   identifiable and a test of it means something;
#' * it adds columns and fewer dimensions, so some of its terms are aliased
#'   with terms already in the model and the degrees of freedom a test would
#'   claim are not the degrees of freedom it has;
#' * it adds no dimension at all, so there is nothing to test. A p-value here
#'   is the most dangerous number in the whole screen: it is near one, it looks
#'   like evidence of no interaction, and it is evidence of nothing.
#'
#' The reduced model's own rank is reported beside them, because a reduced
#' model that is already deficient makes every difference computed against it
#' unreliable, however healthy the increment looks.
#'
#' @param project A [mm_project()].
#' @param frame The development rows, after eligibility.
#' @param pair The two predictor names.
#' @param nonlinear Predictors fitted with splines.
#' @param knots Knots for those splines.
#' @return A list with `base_columns`, `base_rank`, `added_columns`,
#'   `added_rank`, `identifiable`, `aliased` and `reason`.
#' @keywords internal
mm_interaction_rank <- function(project, frame, pair, nonlinear = NULL,
                                knots = 4L) {
  term_of <- function(p) {
    if (p %in% (nonlinear %||% character(0))) {
      sprintf("rms::rcs(%s, %d)", p, as.integer(knots))
    } else p
  }
  columns_of <- function(terms_rhs) {
    formula <- stats::as.formula(
      paste("~", paste(terms_rhs, collapse = " + ")), env = baseenv())
    matrix <- stats::model.matrix(formula, data = frame)
    matrix[, setdiff(colnames(matrix), "(Intercept)"), drop = FALSE]
  }
  main <- vapply(project$predictors, term_of, character(1))
  block <- paste(term_of(pair[1]), term_of(pair[2]), sep = ":")
  reduced <- columns_of(main)
  full <- columns_of(c(main, block))

  base_rank <- mm_matrix_rank(reduced)
  added_columns <- ncol(full) - ncol(reduced)
  added_rank <- mm_matrix_rank(full) - base_rank

  identifiable <- added_rank > 0L && added_rank == added_columns
  reason <- if (added_rank == 0L) {
    sprintf(paste("the block adds %d column(s) and no dimension: every term",
                  "it contributes is a combination of terms already in the",
                  "model, so there is nothing for a test to be about"),
            added_columns)
  } else if (added_rank < added_columns) {
    sprintf(paste("the block adds %d column(s) but only %d dimension(s), so",
                  "%d of its terms are aliased with terms already in the",
                  "model and a test would claim more degrees of freedom than",
                  "it has"),
            added_columns, added_rank, added_columns - added_rank)
  } else if (base_rank < ncol(reduced)) {
    sprintf(paste("identifiable, but the model without it is already rank",
                  "deficient: %d column(s) span %d dimension(s), so any",
                  "difference taken against it is unreliable"),
            ncol(reduced), base_rank)
  } else ""

  list(base_columns = ncol(reduced), base_rank = base_rank,
       added_columns = added_columns, added_rank = added_rank,
       identifiable = identifiable,
       aliased = added_rank < added_columns,
       base_deficient = base_rank < ncol(reduced),
       reason = reason)
}

#' Support and separation for one candidate, reported and never decisive
#'
#' Sparse is not the same as unidentifiable, and this function exists to keep
#' them apart. A cell carrying twelve rows and no events leaves the design
#' matrix at full rank: the interaction is estimable, the likelihood is close
#' to flat in that direction, and the test returns a statistic near zero with a
#' p-value near one. That is worth saying out loud beside the p-value, and it
#' is not grounds for refusing to report the test, because the same shape
#' arises in a cohort where the interaction is simply small.
#'
#' Only [mm_interaction_rank()] decides whether a test is reported.
#'
#' @param frame The development rows.
#' @param pair The two predictor names.
#' @param y The 0/1 outcome for those rows.
#' @return A list of counts and flags, with `note` describing anything found.
#' @keywords internal
mm_interaction_support <- function(frame, pair, y) {
  categorical <- vapply(pair, function(p)
    is.factor(frame[[p]]) || is.character(frame[[p]]) ||
      is.logical(frame[[p]]), logical(1))
  grid <- if (all(categorical)) {
    interaction(as.character(frame[[pair[1]]]),
                as.character(frame[[pair[2]]]), drop = FALSE, sep = " x ")
  } else if (any(categorical)) {
    factor(as.character(frame[[pair[categorical][1]]]))
  } else NULL

  if (is.null(grid)) {
    continuous <- paste("both predictors are continuous, so there are no",
                        "cells to count")
    return(list(cells = 0L, empty_cells = 0L, cells_without_events = 0L,
                cells_without_non_events = 0L, smallest_cell = NA_integer_,
                counts = continuous, note = continuous))
  }
  counts <- table(grid)
  events <- tapply(y, grid, sum)
  events[is.na(events)] <- 0L
  non_events <- counts - events
  empty <- sum(counts == 0L)
  no_events <- sum(counts > 0L & events == 0L)
  no_non_events <- sum(counts > 0L & non_events == 0L)

  parts <- character(0)
  if (empty > 0L) {
    parts <- c(parts, sprintf("%d combination(s) carry no rows", empty))
  }
  if (no_events > 0L) {
    parts <- c(parts, sprintf(paste("%d populated combination(s) carry no",
                                    "events"), no_events))
  }
  if (no_non_events > 0L) {
    parts <- c(parts, sprintf(paste("%d populated combination(s) carry no",
                                    "non-events"), no_non_events))
  }
  # Two forms. `counts` states what the table holds and is safe to print
  # beside a block that was never tested; `note` adds what a near-null test
  # on these counts means, which is only coherent where a test was reported.
  plain <- if (!length(parts)) {
    sprintf("smallest combination carries %d row(s)", min(counts[counts > 0L]))
  } else paste(parts, collapse = ", ")
  note <- if (!length(parts)) plain else {
    paste0(plain,
           ". The estimate is at or near the edge of the likelihood, so a ",
           "statistic near zero and a p-value near one describe the sparsity ",
           "and not the absence of an interaction")
  }
  list(cells = length(counts), empty_cells = empty, counts = plain,
       cells_without_events = no_events,
       cells_without_non_events = no_non_events,
       smallest_cell = if (any(counts > 0L)) min(counts[counts > 0L]) else 0L,
       note = note)
}

#' The row of an rms anova table belonging to one interaction block
#' @param table An [rms::anova.rms()] result.
#' @param pair The two predictor names.
#' @return The row index, or `NA_integer_`.
#' @keywords internal
mm_anova_block <- function(table, pair) {
  labels <- rownames(table)
  crossed <- grepl("*", labels, fixed = TRUE)
  holds <- vapply(seq_along(labels), function(i)
    all(vapply(pair, function(p) grepl(p, labels[i], fixed = TRUE),
               logical(1))), logical(1))
  hit <- which(crossed & holds)
  if (!length(hit)) NA_integer_ else hit[1]
}

#' Test prespecified interactions, and report what the test rests on
#'
#' Evaluates each candidate interaction as an addition to the project's
#' main-effects model and reports the evidence for it. It returns evidence and
#' nothing else: no model is modified, no term is added, and no interaction
#' reaches a nomogram because a p-value was small. Deciding what the model
#' contains stays with the analyst, which is what makes this a diagnostic
#' rather than a selection procedure.
#'
#' Each candidate is one block tested against one reduced model, the project's
#' main effects. They are therefore `length(candidates)` separate comparisons
#' and not a sequence: a block is never tested against a model containing
#' another candidate, because that would make the answer depend on the order
#' they were listed in.
#'
#' @section What is reported, and what is withheld:
#'
#' A test is reported only for a block that is identifiable, which
#' [mm_interaction_rank()] establishes from the design matrix before anything
#' is fitted. A block adding no dimension gets `NA` and a reason, never a
#' p-value: such a block produces a statistic near zero and a p-value near
#' one, which reads as evidence that the interaction is absent when it is
#' evidence of nothing at all.
#'
#' Sparsity is reported beside the test and never withholds it. A combination
#' carrying no events leaves the design matrix at full rank, so the
#' interaction is estimable and the near-null result describes the sparsity.
#' Refusing the test there would also refuse the cohorts where an interaction
#' is real and small.
#'
#' @section The two tests:
#'
#' `test = "LR"` is a likelihood-ratio test from the difference in deviance
#' between the reduced fit and the fit with the block added, on verifiably the
#' same rows, cross-checked against [rms::anova.rms()] with `test = "LR"`.
#' Both numbers are returned, and `lr_agrees` records whether they match, so
#' the claim is checked on every call rather than once in a test file.
#'
#' `test = "Wald"` is the joint Wald test of the whole block from
#' [rms::anova.rms()], which is several degrees of freedom whenever a
#' categorical or spline term is involved. It is never the test of one dummy
#' coefficient.
#'
#' @section Multiplicity, and what it does not fix:
#'
#' `adjustment` applies [stats::p.adjust()] across the candidates and the
#' unadjusted value is always kept beside it. An adjusted p-value addresses
#' having looked at several blocks. It does not address choosing a model from
#' the result and then validating it on the same data, which is optimism from
#' selection and needs the selection repeated inside the resampling. That is
#' not in this function.
#'
#' @param project A [mm_project()].
#' @param cohort The cohort. Its development rows are used, under the same
#'   eligibility rule [mm_model()] fits under, and the digest is checked so
#'   the screen cannot run on a different sample from the model.
#' @param candidates List of length-two character vectors naming the blocks to
#'   evaluate. Prespecified: this argument is a hypothesis, not a search.
#' @param test `"LR"` or `"Wald"`.
#' @param adjustment `"none"`, `"BH"` or `"holm"`.
#' @param nonlinear,knots Passed to [mm_model()], because the shape of the
#'   model under test decides the degrees of freedom a block costs.
#'
#' @return An object of class `mm_interaction_screen`.
#'
#' @examples
#' cohort <- mm_synthetic_cohort(n = 600, prevalence = 0.15, seed = 1978)
#' project <- mm_project("uds", "event",
#'                       c("age", "bmi", "sex", "prior_uti"),
#'                       positive_class = 1, cohort = cohort)
#' mm_interactions(project, cohort,
#'                 candidates = list(c("prior_uti", "sex"),
#'                                   c("age", "bmi")))
#' @export
mm_interactions <- function(project, cohort, candidates,
                            test = c("LR", "Wald"),
                            adjustment = c("none", "BH", "holm"),
                            nonlinear = NULL, knots = 4L) {
  if (!inherits(project, "mm_project")) {
    stop("`project` must come from mm_project().", call. = FALSE)
  }
  if (!is.data.frame(cohort)) {
    stop("`cohort` must be a data frame.", call. = FALSE)
  }
  test <- match.arg(test)
  adjustment <- match.arg(adjustment)
  parsed <- mm_candidate_pairs(project, candidates)

  message("mm_interactions(): ", length(parsed), " prespecified block(s), ",
          test, " test, multiplicity ", adjustment)

  # The rows the main-effects model will be fitted on, derived the same way
  # mm_model() derives them and then checked against it, so the design
  # matrices below describe the sample the tests are computed on.
  base <- suppressWarnings(
    mm_model(project, cohort, nonlinear = nonlinear, knots = knots))
  parts <- mm_split(project, cohort)
  eligible <- mm_evaluable(project, parts$dev, require_cluster = TRUE)
  frame <- parts$dev[eligible$usable, , drop = FALSE]
  for (p in project$predictors) {
    if (is.factor(frame[[p]])) frame[[p]] <- droplevels(frame[[p]])
  }
  mm_same_development(base, frame, "every interaction test below")
  y <- mm_event_indicator(frame[[project$outcome]], project$positive_class)
  base_deviance <- unname(base$fit$deviance[length(base$fit$deviance)])
  base_df <- unname(base$fit$stats[["d.f."]])

  rows <- lapply(parsed, function(candidate) {
    pair <- candidate$pair
    rank <- mm_interaction_rank(project, frame, pair, nonlinear, knots)
    support <- mm_interaction_support(frame, pair, y)
    blank <- data.frame(
      interaction = candidate$label, predictor_1 = pair[1],
      predictor_2 = pair[2], mode = "prespecified", test_method = test,
      statistic = NA_real_, degrees_freedom = NA_integer_,
      p_value = NA_real_, n_evaluable = nrow(frame), events = sum(y),
      nonevents = length(y) - sum(y),
      added_parameters = rank$added_columns, added_rank = rank$added_rank,
      base_rank = rank$base_rank, base_columns = rank$base_columns,
      cells = support$cells, smallest_cell = support$smallest_cell,
      cells_without_events = support$cells_without_events,
      converged = NA, estimable = rank$identifiable,
      lr_reference = NA_real_, lr_agrees = NA,
      status = NA_character_, reason = NA_character_,
      stringsAsFactors = FALSE)

    if (!rank$identifiable) {
      blank$status <- if (rank$added_rank == 0L) "not_estimable" else "aliased"
      blank$reason <- paste0(rank$reason, ". ", support$counts)
      return(blank)
    }

    fitted <- tryCatch(
      suppressWarnings(mm_model(project, cohort, nonlinear = nonlinear,
                                knots = knots,
                                interactions = list(pair))),
      error = function(e) conditionMessage(e))
    if (is.character(fitted)) {
      blank$status <- "fit_failed"
      blank$converged <- FALSE
      blank$reason <- paste0("the model with this block could not be fitted: ",
                             fitted, ". ", support$counts)
      return(blank)
    }
    mm_same_development(fitted, frame, paste("the test of", candidate$label))

    added_df <- unname(fitted$fit$stats[["d.f."]]) - base_df
    if (added_df != rank$added_rank) {
      blank$status <- "not_estimable"
      blank$reason <- sprintf(
        paste("the fit spends %d degree(s) of freedom on a block worth %d",
              "dimension(s), so the reference distribution for a test of it",
              "is not the one a difference in degrees of freedom implies"),
        added_df, rank$added_rank)
      return(blank)
    }

    old <- options(datadist = fitted$datadist)
    on.exit(options(old), add = TRUE)
    table <- tryCatch(
      stats::anova(fitted$fit, test = if (test == "LR") "LR" else "Chisq"),
      error = function(e) conditionMessage(e))
    if (is.character(table)) {
      blank$status <- "not_supported"
      blank$converged <- isFALSE(fitted$fit$fail)
      blank$reason <- paste0("rms could not produce a ", test,
                             " table for this fit: ", table)
      return(blank)
    }
    hit <- mm_anova_block(table, pair)

    blank$converged <- isFALSE(fitted$fit$fail)
    blank$degrees_freedom <- rank$added_rank
    if (test == "LR") {
      # From the deviances, on rows whose digest has just been checked twice.
      full_deviance <- unname(
        fitted$fit$deviance[length(fitted$fit$deviance)])
      blank$statistic <- base_deviance - full_deviance
      blank$lr_reference <- if (is.na(hit)) NA_real_ else
        unname(table[hit, "Chi-Square"])
      blank$lr_agrees <- !is.na(blank$lr_reference) &&
        isTRUE(all.equal(blank$statistic, blank$lr_reference,
                         tolerance = 1e-4))
    } else {
      blank$statistic <- if (is.na(hit)) NA_real_ else
        unname(table[hit, "Chi-Square"])
    }
    if (is.na(blank$statistic)) {
      blank$status <- "not_estimable"
      blank$reason <- paste("rms reported no row for this block, so no",
                            "statistic was read rather than one guessed")
      return(blank)
    }
    blank$p_value <- stats::pchisq(blank$statistic, rank$added_rank,
                                   lower.tail = FALSE)
    blank$status <- "tested"
    blank$reason <- support$note
    if (nzchar(rank$reason)) {
      blank$reason <- paste0(rank$reason, ". ", blank$reason)
    }
    if (test == "LR" && isFALSE(blank$lr_agrees)) {
      blank$status <- "disagreement"
      blank$reason <- sprintf(
        paste("the deviance difference is %.6f and rms::anova(test = \"LR\")",
              "reports %.6f. Two routes to one statistic disagree, so",
              "neither is reported as the answer. %s"),
        blank$statistic, blank$lr_reference, blank$reason)
    }
    blank
  })

  screen <- do.call(rbind, rows)
  tested <- screen$status %in% c("tested")
  screen$p_adjusted <- NA_real_
  if (any(tested)) {
    screen$p_adjusted[tested] <- if (adjustment == "none") {
      screen$p_value[tested]
    } else stats::p.adjust(screen$p_value[tested], method = adjustment)
  }
  screen <- screen[, c("interaction", "predictor_1", "predictor_2", "mode",
                       "test_method", "statistic", "degrees_freedom",
                       "p_value", "p_adjusted", "n_evaluable", "events",
                       "nonevents", "added_parameters", "added_rank",
                       "base_columns", "base_rank", "cells",
                       "smallest_cell", "cells_without_events", "converged",
                       "estimable", "lr_reference", "lr_agrees", "status",
                       "reason")]

  structure(
    list(screen = screen, mode = "prespecified", test = test,
         adjustment = adjustment, n_candidates = length(parsed),
         candidate_parameters = sum(screen$added_parameters),
         base = list(n_dev = base$n_dev, events = base$events_dev,
                     parameters = length(stats::coef(base$fit)) - 1L,
                     fingerprint = base$fingerprint,
                     development = base$development,
                     adequacy = base$adequacy),
         nonlinear = nonlinear, knots = as.integer(knots)),
    class = "mm_interaction_screen")
}

#' @export
print.mm_interaction_screen <- function(x, ...) {
  s <- x$screen
  cat("<mm_interaction_screen>  ", x$mode, ", ", x$test, " test\n", sep = "")
  cat("  development ", x$base$n_dev, " rows, ", x$base$events,
      " events, ", x$base$parameters, " parameter(s) before any block\n",
      sep = "")
  cat("  candidates  ", x$n_candidates, " block(s) considered, ",
      x$candidate_parameters,
      " parameter(s) of candidate complexity in total\n", sep = "")
  for (i in seq_len(nrow(s))) {
    cat(sprintf("  %-22s %s", s$interaction[i], s$status[i]))
    if (identical(s$status[i], "tested")) {
      cat(sprintf("  chi2=%.3f df=%d p=%.4f", s$statistic[i],
                  s$degrees_freedom[i], s$p_value[i]))
      if (!identical(x$adjustment, "none")) {
        cat(sprintf(" p.adj=%.4f", s$p_adjusted[i]))
      }
    }
    cat("\n")
  }
  withheld <- s[!s$status %in% "tested", , drop = FALSE]
  if (nrow(withheld)) {
    cat("  no test was reported for ", nrow(withheld), " block(s):\n",
        sep = "")
    for (i in seq_len(nrow(withheld))) {
      cat("    ", withheld$interaction[i], ": ",
          paste(strwrap(withheld$reason[i], 66,
                        prefix = "\n      ", initial = ""),
                collapse = ""), "\n", sep = "")
    }
  }
  cat("  Evidence about blocks, not a model. Nothing here has been added to\n")
  cat("  a model, and a small p-value is not a reason to add it: the\n")
  cat("  optimism of choosing on these data is not corrected by this\n")
  cat("  function.\n")
  invisible(x)
}
