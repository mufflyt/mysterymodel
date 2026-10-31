# Every test here either compares against an independently computed reference
# or asserts a scientific property. None records a number the function
# happened to produce.

ia_cohort <- function(n = 900, prevalence = 0.18, seed = 1978) {
  mm_synthetic_cohort(n = n, prevalence = prevalence, seed = seed)
}
ia_project <- function(cohort,
                       predictors = c("age", "bmi", "sex", "prior_uti",
                                      "indication")) {
  mm_project("uds", "event", predictors, positive_class = 1,
             cohort = cohort, seed = 1978)
}
# The likelihood-ratio statistic from two models fitted here, by deviance,
# with the rows proved identical first.
reference_lr <- function(project, cohort, pair, nonlinear = NULL) {
  base <- suppressWarnings(mm_model(project, cohort, nonlinear = nonlinear))
  full <- suppressWarnings(mm_model(project, cohort, nonlinear = nonlinear,
                                    interactions = list(pair)))
  stopifnot(identical(base$development, full$development))
  statistic <- unname(base$fit$deviance[length(base$fit$deviance)]) -
    unname(full$fit$deviance[length(full$fit$deviance)])
  added <- unname(full$fit$stats[["d.f."]] - base$fit$stats[["d.f."]])
  list(statistic = statistic, df = added,
       p = stats::pchisq(statistic, added, lower.tail = FALSE))
}

test_that("a correctly specified LR test matches an independent fit", {
  cohort <- ia_cohort()
  project <- ia_project(cohort)
  pairs <- list(c("prior_uti", "sex"), c("sex", "indication"),
                c("age", "bmi"))
  screen <- suppressMessages(mm_interactions(project, cohort, pairs))

  for (i in seq_along(pairs)) {
    ref <- reference_lr(project, cohort, pairs[[i]])
    row <- screen$screen[i, ]
    expect_equal(row$statistic, ref$statistic, tolerance = 1e-8)
    expect_equal(row$degrees_freedom, ref$df)
    expect_equal(row$p_value, ref$p, tolerance = 1e-10)
    # And the function's own cross-check against rms agreed on every row.
    expect_true(row$lr_agrees)
    expect_equal(row$lr_reference, ref$statistic, tolerance = 1e-4)
  }
})

test_that("a Wald test is the joint test of the whole block", {
  # Several degrees of freedom whenever a categorical or spline is involved,
  # never the test of one dummy coefficient.
  cohort <- ia_cohort()
  project <- ia_project(cohort)
  wald <- suppressMessages(mm_interactions(
    project, cohort, list(c("sex", "indication")), test = "Wald"))
  expect_equal(wald$screen$degrees_freedom, 2L)
  expect_equal(wald$screen$test_method, "Wald")

  full <- suppressWarnings(mm_model(project, cohort,
                                    interactions = list(c("sex",
                                                          "indication"))))
  old <- options(datadist = full$datadist)
  on.exit(options(old), add = TRUE)
  table <- stats::anova(full$fit, test = "Chisq")
  hit <- mysterymodel:::mm_anova_block(table, c("sex", "indication"))
  expect_equal(wald$screen$statistic, unname(table[hit, "Chi-Square"]),
               tolerance = 1e-10)
  expect_equal(unname(table[hit, "d.f."]), 2)

  # Wald and LR are different tests and are labelled as the one computed.
  lr <- suppressMessages(mm_interactions(project, cohort,
                                         list(c("sex", "indication"))))
  expect_equal(lr$screen$test_method, "LR")
  expect_false(isTRUE(all.equal(lr$screen$statistic,
                                wald$screen$statistic)))
})

test_that("a spline interaction keeps its own degrees of freedom", {
  # Three for rcs(age, 4) crossed with a binary factor, which is what the
  # model actually spends. A linear interaction must never be substituted.
  cohort <- ia_cohort()
  project <- ia_project(cohort, c("age", "bmi", "sex"))
  curved <- suppressMessages(mm_interactions(
    project, cohort, list(c("age", "sex")), nonlinear = "age"))
  ref <- reference_lr(project, cohort, c("age", "sex"), nonlinear = "age")
  expect_equal(curved$screen$degrees_freedom, 3L)
  expect_equal(ref$df, 3L)
  expect_equal(curved$screen$statistic, ref$statistic, tolerance = 1e-8)

  straight <- suppressMessages(mm_interactions(project, cohort,
                                               list(c("age", "sex"))))
  expect_equal(straight$screen$degrees_freedom, 1L)
  expect_false(isTRUE(all.equal(curved$screen$statistic,
                                straight$screen$statistic)))
})

test_that("a rank-deficient block is never given a p-value", {
  # `flag` only takes "yes" when sex is male, so its interaction with sex is
  # a copy of its main effect. The block adds a column and no dimension, and
  # rms answers the fit with a singular Hessian. A near-null p-value here
  # would read as evidence that the interaction is absent.
  cohort <- ia_cohort()
  cohort$flag <- factor("no", levels = c("no", "yes"))
  cohort$flag[cohort$sex == "male"][1:40] <- "yes"
  project <- ia_project(cohort, c("age", "sex", "flag"))

  rank <- mysterymodel:::mm_interaction_rank(
    project, cohort, c("sex", "flag"))
  expect_equal(rank$added_columns, 1L)
  expect_equal(rank$added_rank, 0L)
  expect_false(rank$identifiable)

  screen <- suppressMessages(mm_interactions(project, cohort,
                                             list(c("sex", "flag"))))
  expect_equal(screen$screen$status, "not_estimable")
  expect_true(is.na(screen$screen$p_value))
  expect_true(is.na(screen$screen$statistic))
  expect_true(is.na(screen$screen$p_adjusted))
  expect_match(screen$screen$reason, "no dimension")
  # The candidate is still reported rather than dropped from the table.
  expect_equal(nrow(screen$screen), 1L)
  expect_equal(screen$n_candidates, 1L)
})

test_that("a sparse but identifiable block is tested, not refused", {
  # Twelve rows and no events in one combination. The design matrix stays at
  # full rank, so the interaction is estimable and the near-null result
  # describes the sparsity. Refusing it would also refuse every cohort where
  # an interaction is real and small.
  cohort <- ia_cohort()
  cohort$rare <- factor(ifelse(seq_len(nrow(cohort)) <= 12, "yes", "no"),
                        levels = c("no", "yes"))
  cohort$event[cohort$rare == "yes"] <- 0
  project <- ia_project(cohort, c("age", "sex", "rare"))

  rank <- mysterymodel:::mm_interaction_rank(project, cohort,
                                             c("sex", "rare"))
  expect_equal(rank$added_rank, rank$added_columns)
  expect_true(rank$identifiable)

  screen <- suppressMessages(mm_interactions(project, cohort,
                                             list(c("sex", "rare"))))
  expect_equal(screen$screen$status, "tested")
  expect_false(is.na(screen$screen$p_value))
  expect_gt(screen$screen$cells_without_events, 0L)
  expect_match(screen$screen$reason, "no events")
  expect_match(screen$screen$reason, "not the absence of an interaction")
})

test_that("a populated table can still be rank deficient", {
  # Estimability is not a property of the contingency table. Here every cell
  # is populated and the block is still a combination of existing terms.
  cohort <- ia_cohort()
  cohort$relabelled <- factor(ifelse(cohort$sex == "male", "m", "f"))
  expect_true(all(table(cohort$sex, cohort$relabelled)[c(1, 4)] > 0))
  expect_equal(sum(table(cohort$sex, cohort$relabelled) == 0), 2L)

  project <- ia_project(cohort, c("age", "sex", "relabelled"))
  rank <- mysterymodel:::mm_interaction_rank(project, cohort,
                                             c("sex", "relabelled"))
  expect_equal(rank$added_rank, 0L)
  expect_false(rank$identifiable)
  expect_true(rank$base_deficient)
})

test_that("a block whose added rank is zero cannot be reported as tested", {
  # The invariant, asserted directly: no row may carry a p-value unless the
  # design matrix gained the dimensions the test claims.
  cohort <- ia_cohort()
  cohort$flag <- factor("no", levels = c("no", "yes"))
  cohort$flag[cohort$sex == "male"][1:40] <- "yes"
  cohort$rare <- factor(ifelse(seq_len(nrow(cohort)) <= 12, "yes", "no"),
                        levels = c("no", "yes"))
  project <- ia_project(cohort, c("age", "sex", "flag", "rare"))
  screen <- suppressMessages(mm_interactions(
    project, cohort,
    list(c("sex", "flag"), c("sex", "rare"), c("age", "sex"))))

  reported <- !is.na(screen$screen$p_value)
  expect_true(all(screen$screen$added_rank[reported] ==
                    screen$screen$degrees_freedom[reported]))
  expect_true(all(screen$screen$added_rank[reported] > 0L))
  expect_true(all(screen$screen$estimable[reported]))
  # Every candidate appears, tested or not.
  expect_equal(nrow(screen$screen), 3L)
  expect_setequal(screen$screen$interaction,
                  c("sex x flag", "sex x rare", "age x sex"))
})

test_that("candidates are checked before anything is fitted", {
  cohort <- ia_cohort()
  project <- ia_project(cohort)
  expect_error(mm_interactions(project, cohort, list(c("age", "age"))),
               "with itself")
  expect_error(mm_interactions(project, cohort,
                               list(c("age", "sex"), c("sex", "age"))),
               "Reversing a pair")
  expect_error(mm_interactions(project, cohort,
                               list(c("event", "sex"))), "the outcome")
  expect_error(mm_interactions(project, cohort, list(c("age", "weight"))),
               "does not declare")
  expect_error(mm_interactions(project, cohort, list(c("age"))),
               "two non-empty predictor names")
  expect_error(mm_interactions(project, cohort, list()), "non-empty list")
})

test_that("mm_model refuses the same two shapes at the root", {
  # Both used to be accepted and add no term, because a formula reduces a:a
  # to a and keeps one copy of a repeated block, so the parameter budget
  # counted a block the model did not contain.
  cohort <- ia_cohort()
  project <- ia_project(cohort)
  expect_error(mm_model(project, cohort, interactions = list(c("age",
                                                               "age"))),
               "crosses a predictor with itself")
  expect_error(mm_model(project, cohort,
                        interactions = list(c("age", "sex"),
                                            c("age", "sex"))),
               "listed more than once")
  expect_error(mm_model(project, cohort,
                        interactions = list(c("age", "sex"),
                                            c("sex", "age"))),
               "listed more than once")
  expect_no_error(suppressWarnings(
    mm_model(project, cohort, interactions = list(c("prior_uti", "sex")))))
})

test_that("multiplicity is applied across candidates and never replaces the raw value", {
  cohort <- ia_cohort()
  project <- ia_project(cohort)
  pairs <- list(c("prior_uti", "sex"), c("sex", "indication"),
                c("age", "bmi"))
  plain <- suppressMessages(mm_interactions(project, cohort, pairs))
  bh <- suppressMessages(mm_interactions(project, cohort, pairs,
                                         adjustment = "BH"))
  holm <- suppressMessages(mm_interactions(project, cohort, pairs,
                                           adjustment = "holm"))

  expect_equal(plain$screen$p_adjusted, plain$screen$p_value)
  expect_equal(bh$screen$p_adjusted,
               stats::p.adjust(plain$screen$p_value, "BH"))
  expect_equal(holm$screen$p_adjusted,
               stats::p.adjust(plain$screen$p_value, "holm"))
  # The unadjusted value survives every adjustment.
  expect_equal(bh$screen$p_value, plain$screen$p_value)
  expect_true(all(holm$screen$p_adjusted >= holm$screen$p_value))
})

test_that("the candidate budget counts every block considered", {
  # Not only the ones that survive. A screen of three blocks spends the
  # degrees of freedom of three blocks whichever one is reported.
  cohort <- ia_cohort()
  project <- ia_project(cohort)
  screen <- suppressMessages(mm_interactions(
    project, cohort,
    list(c("prior_uti", "sex"), c("sex", "indication"), c("age", "bmi"))))
  expect_equal(screen$n_candidates, 3L)
  expect_equal(screen$candidate_parameters, 1L + 2L + 1L)
  expect_equal(screen$candidate_parameters, sum(screen$screen$added_parameters))
  printed <- paste(capture.output(print(screen)), collapse = " ")
  expect_match(printed, "3 block\\(s\\) considered")
  expect_match(printed, "4 parameter\\(s\\) of candidate complexity")
})

test_that("the screen refuses a cohort the base model was not fitted on", {
  cohort <- ia_cohort()
  project <- ia_project(cohort)
  altered <- cohort
  altered$age <- rev(altered$age)
  expect_error(
    suppressMessages(mm_interactions(project, altered,
                                     list(c("prior_uti", "sex")))),
    NA)
  # The guard that matters: the frame the design matrices are built from is
  # the frame the base model was fitted on, checked by digest.
  expect_equal(
    suppressMessages(mm_interactions(project, cohort,
                                     list(c("prior_uti", "sex"))))$base$development,
    suppressWarnings(mm_model(project, cohort))$development)
})

test_that("no interaction is added to any model by screening", {
  # The governing principle. The screen returns evidence and the base model's
  # fingerprint is the no-interaction fingerprint, unchanged.
  cohort <- ia_cohort()
  project <- ia_project(cohort)
  before <- suppressWarnings(mm_model(project, cohort))
  screen <- suppressMessages(mm_interactions(
    project, cohort, list(c("prior_uti", "sex"), c("age", "bmi"))))
  after <- suppressWarnings(mm_model(project, cohort))

  expect_identical(before$fingerprint, after$fingerprint)
  expect_identical(screen$base$fingerprint, before$fingerprint)
  expect_equal(length(stats::coef(after$fit)),
               length(stats::coef(before$fit)))
  expect_false(any(grepl("[*:]", names(stats::coef(after$fit)))))
  printed <- paste(capture.output(print(screen)), collapse = " ")
  expect_match(printed, "Evidence about blocks, not a model")
})

test_that("penalization and imputation stay out of reach rather than guarded", {
  # Pinned assumptions. mm_model() cannot produce a penalized fit and the
  # package has no imputation, so mm_interactions() never meets either. If
  # that changes, this fails and the inferential restrictions in DEC-008
  # have to be built before the capability ships.
  expect_false("penalty" %in% names(formals(mm_model)))
  expect_false(any(grepl("penalty", names(formals(mm_interactions)))))
  expect_false(any(grepl("impute|imputation",
                         names(getNamespaceExports("mysterymodel")))))
})
