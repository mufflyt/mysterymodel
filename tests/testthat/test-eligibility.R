# Finding 3, settled as DEC-003: complete-case fitting is retained, and
# validation is made cohort-aware so that the sample a model is judged against
# is the sample it was fitted on. One rule, read by fitting and by both kinds
# of validation, so the two cannot be decided separately and differently.

mixed_cohort <- function(seed = 1978) {
  cohort <- mm_synthetic_cohort(n = 600, seed = seed)
  held <- which(cohort$year >= 2023)
  cohort$bmi[1:25] <- NA                    # development, missing predictor
  cohort$bmi[held[1:9]] <- NA               # external, missing predictor
  cohort$event[held[20:27]] <- NA           # external, missing OUTCOME
  cohort$bmi[held[26:30]] <- NA             # and the overlap of the two
  cohort
}

mixed_project <- function() {
  mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
             positive_class = 1, split_var = "year", split_at = 2023,
             cluster_id = "pid", seed = 1978)
}

test_that("a missing predictor and a missing outcome are counted apart", {
  project <- mixed_project()
  cohort <- mixed_cohort()
  held <- cohort[cohort$year >= 2023, , drop = FALSE]
  e <- mm_evaluable(project, held)

  no_pred <- is.na(held$bmi) | is.na(held$age) | is.na(held$sex) |
    is.na(held$prior_uti)
  no_out <- is.na(held$event)

  expect_equal(e$n_total, nrow(held))
  expect_equal(e$n_scored, sum(!no_pred & !no_out))
  expect_equal(e$missing_predictor, sum(no_pred & !no_out))
  expect_equal(e$missing_outcome, sum(no_out & !no_pred))
  expect_equal(e$missing_both, sum(no_pred & no_out))
  expect_equal(e$n_excluded,
               e$missing_predictor + e$missing_outcome + e$missing_both)

  # All three are non-zero in this fixture, so the test would not pass by
  # accident if two of the categories were collapsed into one.
  expect_gt(e$missing_predictor, 0)
  expect_gt(e$missing_outcome, 0)
  expect_gt(e$missing_both, 0)
})

test_that("a missing outcome is excluded, never counted as a non-event", {
  project <- mixed_project()
  cohort <- mixed_cohort()
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- suppressWarnings(mm_validate(model, cohort, B = 10))

  held <- cohort[cohort$year >= 2023, , drop = FALSE]
  e <- mm_evaluable(project, held)
  row <- v$metrics[v$metrics$basis == "held out", ]

  expect_equal(row$n, e$n_scored)
  expect_lt(row$n, nrow(held))
  # The events are those among the scored rows. Treating the missing outcomes
  # as non-events would leave the event count the same but inflate n.
  expect_equal(row$events, sum(held$event[e$usable] == 1L))
})

test_that("validation scores the sample the model was fitted on", {
  project <- mixed_project()
  cohort <- mixed_cohort()
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- suppressWarnings(mm_validate(model, cohort, B = 10,
                                    full_process = TRUE))

  apparent <- v$metrics[v$metrics$basis == "apparent", ]
  expect_equal(apparent$n, model$n_dev)
  expect_equal(apparent$events, model$events_dev)

  # Both bootstrap rows describe the fitted cohort too, and the full-process
  # one resampled it rather than the frame it was handed.
  for (b in c("bootstrap, fixed model", "bootstrap, full process")) {
    expect_equal(v$metrics$n[v$metrics$basis == b], model$n_dev)
  }
  expect_equal(v$full_process_detail$eligibility$n_scored, model$n_dev)
  expect_lt(v$full_process_detail$eligibility$n_scored,
            v$full_process_detail$eligibility$n_total)
})

test_that("the exclusions reach the report, not just the arithmetic", {
  project <- mixed_project()
  cohort <- mixed_cohort()
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- suppressWarnings(mm_validate(model, cohort, B = 10))

  expect_equal(v$eligibility$development$n_scored, model$n_dev)
  expect_false(is.null(v$eligibility$held_out))
  expect_match(v$metrics$note[v$metrics$basis == "held out"],
               "missing outcome")
  expect_match(v$metrics$note[v$metrics$basis == "held out"],
               "Complete case")

  # The caveat travels with the number. Complete-case analysis is a
  # computational strategy, not a guarantee that the exclusions were ignorable.
  expect_match(v$metrics$note[v$metrics$basis == "apparent"],
               "assumption and not a finding")

  # And the masks are not retained, so the report carries counts rather than
  # a row-shaped artefact of the cohort.
  expect_false("usable" %in% names(v$eligibility$held_out))
  expect_false("usable" %in% names(model$eligibility))
})

test_that("zero evaluable rows are reported, not omitted or crashed", {
  cohort <- mm_synthetic_cohort(n = 600, seed = 1978)
  cohort$bmi[cohort$year >= 2023] <- NA
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, split_var = "year",
                        split_at = 2023, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  expect_warning(v <- mm_validate(model, cohort, B = 10),
                 "none of the 196 held-out row")
  row <- v$metrics[v$metrics$basis == "held out", ]
  expect_equal(nrow(row), 1L)
  expect_equal(row$n, 0L)
  expect_true(is.na(row$c_stat))
  expect_match(row$note, "nothing to estimate")
})

test_that("an outcome that does not vary gives no estimate and says why", {
  cohort <- mm_synthetic_cohort(n = 600, seed = 1978)
  cohort$event[cohort$year >= 2023] <- 0L
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, split_var = "year",
                        split_at = 2023, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- suppressWarnings(mm_validate(model, cohort, B = 10))

  row <- v$metrics[v$metrics$basis == "held out", ]
  expect_equal(row$n, 196L)
  expect_equal(row$events, 0L)
  expect_true(is.na(row$c_stat))
  expect_match(row$note, "discrimination is undefined")
})

test_that("an unseen level is still refused rather than excluded", {
  # DEC-003 keeps this a refusal. Quietly excluding those patients would
  # change the evaluated population without saying so, and collapsing the
  # level is a modelling decision that belongs to the analyst.
  cohort <- mm_synthetic_cohort(n = 600, seed = 1978)
  cohort$indication <- as.character(cohort$indication)
  cohort$indication[which(cohort$year >= 2023)[1:3]] <- "urgency"
  cohort$indication <- factor(cohort$indication)
  project <- mm_project("uds", "event", c("age", "bmi", "indication"),
                        positive_class = 1, split_var = "year",
                        split_at = 2023, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  expect_error(suppressWarnings(mm_validate(model, cohort, B = 5)),
               "never saw: urgency")
})

test_that("validating against a different cohort is refused", {
  project <- mixed_project()
  model <- suppressWarnings(mm_model(project, mixed_cohort(), nonlinear = "age"))
  other <- mm_synthetic_cohort(n = 500, seed = 99)
  expect_error(suppressWarnings(mm_validate(model, other, B = 5)),
               "not the cohort the model was developed on")
})

test_that("mm_predict keeps refusing a missing predictor by default", {
  # DEC-003 is explicit that the complete-case path belongs to validation and
  # does not relax this. A probability for a patient whose predictors are
  # unknown is the thing this default exists to withhold.
  cohort <- mm_synthetic_cohort(n = 300, seed = 1978)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  gap <- cohort[1, ]
  gap$bmi <- NA
  expect_error(mm_predict(model, gap), "missing predictor")
  expect_true(is.na(mm_predict(model, gap, on_missing = "na")$.pred))
})

test_that("complete data is unaffected in every reported number", {
  cohort <- mm_synthetic_cohort(n = 500, seed = 1978)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort,
                        split_var = "year", split_at = 2023, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- mm_validate(model, cohort, B = 10)

  expect_equal(model$eligibility$n_excluded, 0L)
  expect_equal(v$eligibility$development$n_excluded, 0L)
  expect_equal(v$eligibility$held_out$n_excluded, 0L)
  expect_equal(v$metrics$n[v$metrics$basis == "apparent"], model$n_dev)
  # No eligibility sentence is added when there is nothing to report.
  expect_equal(v$metrics$note[v$metrics$basis == "apparent"],
               "scored on the development rows")
  expect_no_match(v$metrics$note[v$metrics$basis == "held out"],
                  "Complete case")
})
