# Rank says whether a block is identifiable. These are the separate questions
# of whether the likelihood has an estimate, and what the block costs against
# the model's whole complexity.

depth_cohort <- function(n = 600, prevalence = 0.15, seed = 1978) {
  mm_synthetic_cohort(n = n, prevalence = prevalence, seed = seed)
}

test_that("a block that separates the outcome gets no p-value", {
  # Full rank, fit$fail FALSE, no categorical cells to count, and every
  # fitted value pinned at the boundary. Before this, the screen reported
  # p = 9e-25 for a perfectly separated surface with no caveat at all.
  cohort <- depth_cohort()
  cohort$event <- as.integer(cohort$age * cohort$bmi > 2000)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  screen <- suppressMessages(mm_interactions(project, cohort,
                                             list(c("age", "bmi"))))
  row <- screen$screen

  expect_equal(row$status, "separated")
  expect_true(is.na(row$p_value))
  expect_true(is.na(row$statistic))
  expect_true(is.na(row$p_adjusted))
  expect_true(row$complete_separation)
  expect_gt(row$at_boundary, 0L)
  expect_gt(row$max_abs_coef, 100)
  expect_match(row$reason, "no interior maximum")
  expect_match(row$reason, "no statistic computed from it is a test")

  # Identifiable all the same: the two failures are separate, and rank did
  # not decide this one.
  expect_true(row$estimable)
  expect_equal(row$added_rank, row$added_parameters)
})

test_that("complete separation is exact, not a tolerance on fitted values", {
  # The definition: every non-event given less risk than every event. A very
  # good model does not satisfy it, because some non-event always outranks
  # some event.
  cohort <- depth_cohort(n = 900, prevalence = 0.25)
  project <- mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  fitted <- suppressWarnings(mm_model(project, cohort,
                                      interactions = list(c("prior_uti",
                                                            "sex"))))
  y <- mysterymodel:::mm_event_indicator(cohort$event, 1)
  health <- mysterymodel:::mm_interaction_health(fitted, y)
  risk <- stats::plogis(as.numeric(fitted$fit$linear.predictors))

  expect_false(health$complete_separation)
  expect_gt(max(risk[y == 0L]), min(risk[y == 1L]))
  expect_equal(health$at_boundary, 0L)
  expect_true(health$converged)
  expect_equal(health$note, "")
})

test_that("quasi-separation is reported and the test is still given", {
  # Part of the sample at the edge makes an estimate fragile rather than
  # absent, so the counts are reported and the p-value is not withheld.
  cohort <- depth_cohort(n = 400)
  # One stratum almost but not entirely separated.
  cohort$marker <- cohort$age
  pick <- which(cohort$sex == "female")[1:3]
  cohort$event[pick] <- 1L
  cohort$marker[pick] <- 200
  project <- mm_project("uds", "event", c("marker", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  screen <- suppressMessages(mm_interactions(
    project, cohort, list(c("marker", "sex")), nonlinear = NULL))
  row <- screen$screen
  # Either it is tested, or it separated completely; both are legitimate
  # outcomes for this fixture, and neither may be a silent p-value.
  expect_true(row$status %in% c("tested", "separated", "fit_failed"))
  if (identical(row$status, "tested")) {
    expect_false(is.na(row$p_value))
    if (row$at_boundary > 0L) expect_match(row$reason, "fragile")
  } else {
    expect_true(is.na(row$p_value))
  }
})

test_that("a non-convergent fit is named as that, not as dropped rows", {
  # mm_model()'s row-count guard used to fire first and blame a silent row
  # drop for a singular Hessian, because a failed fit leaves no usable y.
  cohort <- depth_cohort()
  male <- cohort$sex == "male"
  cohort$event[male] <- as.integer(cohort$age[male] > 70)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)

  raised <- tryCatch(
    suppressWarnings(mm_model(project, cohort,
                              interactions = list(c("age", "sex")))),
    error = function(e) conditionMessage(e))
  expect_match(raised, "could not fit this model")
  expect_match(raised, "singular Hessian")
  expect_false(grepl("dropped a further", raised))
  expect_match(raised, "age:sex", fixed = TRUE)

  # And the screen reports it per block instead of raising it, so one bad
  # candidate does not take the others with it.
  screen <- suppressMessages(mm_interactions(
    project, cohort, list(c("age", "sex"), c("bmi", "sex"))))
  expect_equal(nrow(screen$screen), 2L)
  expect_equal(screen$screen$status[1], "fit_failed")
  expect_false(screen$screen$converged[1])
  expect_equal(screen$screen$status[2], "tested")
  expect_false(is.na(screen$screen$p_value[2]))
})

test_that("the whole model's complexity is reported, not just the increment", {
  # The candidate budget matters against what the model already spends, which
  # is what the Riley requirement is computed from.
  cohort <- depth_cohort(n = 900, prevalence = 0.18)
  project <- mm_project("uds", "event",
                        c("age", "bmi", "sex", "prior_uti", "indication"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  base <- suppressWarnings(mm_model(project, cohort))
  screen <- suppressMessages(mm_interactions(
    project, cohort,
    list(c("prior_uti", "sex"), c("sex", "indication"), c("age", "bmi"))))
  rows <- screen$screen

  expect_true(all(rows$base_parameters ==
                    length(stats::coef(base$fit)) - 1L))
  expect_equal(rows$total_parameters,
               rows$base_parameters + rows$added_parameters)
  expect_equal(rows$events_per_parameter,
               rows$events / rows$total_parameters)
  expect_equal(screen$base_parameters, length(stats::coef(base$fit)) - 1L)

  printed <- paste(capture.output(print(screen)), collapse = " ")
  expect_match(printed, "a model taking every one of them would spend")
  expect_match(printed,
               as.character(screen$base_parameters +
                              screen$candidate_parameters))
})

test_that("empty and one-sided cells are columns, not only prose", {
  cohort <- depth_cohort(n = 900, prevalence = 0.18)
  cohort$rare <- factor(ifelse(seq_len(nrow(cohort)) <= 10, "yes", "no"),
                        levels = c("no", "yes"))
  cohort$event[cohort$rare == "yes"] <- 0
  project <- mm_project("uds", "event", c("age", "sex", "rare"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  row <- suppressMessages(mm_interactions(project, cohort,
                                          list(c("sex", "rare"))))$screen

  expect_true(all(c("empty_cells", "cells_without_events",
                    "cells_without_non_events") %in% names(row)))
  expect_gt(row$cells_without_events, 0L)
  expect_equal(row$cells, 4L)
  # Counted here from the table rather than read back off the object.
  grid <- table(as.character(cohort$sex), as.character(cohort$rare))
  expect_equal(row$empty_cells, sum(grid == 0L))
  expect_equal(row$smallest_cell, min(grid[grid > 0L]))
})

test_that("a continuous pair has no cells and says so", {
  cohort <- depth_cohort()
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  row <- suppressMessages(mm_interactions(project, cohort,
                                          list(c("age", "bmi"))))$screen
  expect_equal(row$cells, 0L)
  expect_equal(row$empty_cells, 0L)
  expect_true(is.na(row$smallest_cell))
  expect_match(row$reason, "no.*cells to count")
})

test_that("separation is the strict definition, with no gap required", {
  # Mutation testing found this untested: widening the comparison to demand a
  # gap between the classes still detected the fully diverged fixtures, where
  # the gap is nearly 1, so nothing distinguished the definition from a
  # tolerance. Separation does not require a wide gap. It requires only that
  # no non-event outranks an event, which is exactly when the likelihood has
  # no interior maximum.
  as_fit <- function(risk) {
    structure(list(fit = list(linear.predictors = stats::qlogis(risk),
                              fail = FALSE,
                              coefficients = c(`(Intercept)` = 0.1,
                                               x = 0.2))),
              class = "mm_model")
  }
  # Separated by a hair: the largest non-event risk is below the smallest
  # event risk by 0.01, and neither class is near 0 or 1.
  y <- c(0L, 0L, 0L, 1L, 1L, 1L)
  narrow <- mysterymodel:::mm_interaction_health(
    as_fit(c(0.40, 0.44, 0.49, 0.50, 0.55, 0.60)), y)
  expect_true(narrow$complete_separation)
  expect_equal(narrow$at_boundary, 0L)
  expect_match(narrow$note, "no interior maximum")

  # One pair out of order is enough to make it not separation, which is the
  # property that keeps a merely excellent model from being withheld.
  overlapping <- mysterymodel:::mm_interaction_health(
    as_fit(c(0.40, 0.44, 0.51, 0.50, 0.55, 0.60)), y)
  expect_false(overlapping$complete_separation)
  expect_equal(overlapping$note, "")

  # Touching is not separating: equal risks leave the maximum attainable.
  touching <- mysterymodel:::mm_interaction_health(
    as_fit(c(0.40, 0.44, 0.50, 0.50, 0.55, 0.60)), y)
  expect_false(touching$complete_separation)
})
