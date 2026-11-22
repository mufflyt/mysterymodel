testthat::test_that("unused column cannot change fitted population", {
  fixture <- mm_adv_fixture()
  altered <- fixture$cohort
  altered$completely_missing_unused <- NA_real_
  fit <- suppressWarnings(mysterymodel::mm_model(
    fixture$project, altered
  ))
  testthat::expect_equal(fit$n_dev, fixture$fit$n_dev)
  testthat::expect_equal(stats::coef(fit), stats::coef(fixture$fit),
                         tolerance = 1e-8)
})

testthat::test_that("one incomplete predictor changes all cohort counts", {
  fixture <- mm_adv_fixture()
  altered <- fixture$cohort
  altered$age[1L] <- NA_real_
  testthat::expect_warning(
    fit <- mysterymodel::mm_model(fixture$project, altered),
    "dropped|incomplete"
  )
  testthat::expect_equal(fit$n_supplied, nrow(altered))
  testthat::expect_equal(fit$n_incomplete, 1L)
  testthat::expect_equal(fit$n_dev, nrow(altered) - 1L)
  testthat::expect_equal(length(fit$fit$y), fit$n_dev)
  testthat::expect_equal(stats::nobs(fit), fit$n_dev)
  testthat::expect_true("age" %in% names(fit$incomplete_by))
})

testthat::test_that("same-sized but different cohort cannot validate", {
  fixture <- mm_adv_fixture()
  altered <- fixture$cohort
  altered$age[1L] <- altered$age[1L] + 2
  testthat::expect_error(
    mysterymodel::mm_validate(fixture$fit, altered, B = 3L),
    "different|same|development|cohort|fingerprint|digest"
  )
})

testthat::test_that("outcome copy is rejected even under a new name", {
  cohort <- mm_adv_fixture()$cohort
  cohort$leak <- cohort$event
  plan <- mysterymodel::mm_project(
    "leak-test", "event", c("age", "bmi", "leak"), cohort = cohort
  )
  testthat::expect_error(
    mysterymodel::mm_model(plan, cohort),
    "leak|outcome|reproduc|duplicat|identical"
  )
})

testthat::test_that("duplicate and self interactions fail at planning", {
  cohort <- mm_adv_fixture()$cohort
  testthat::expect_error(mysterymodel::mm_project(
    "self", "event", c("age", "bmi"), cohort = cohort,
    interactions = list(c("age", "age"))
  ), "itself|self")
  testthat::expect_error(mysterymodel::mm_project(
    "duplicate", "event", c("age", "bmi"), cohort = cohort,
    interactions = list(c("age", "bmi"), c("bmi", "age"))
  ), "more than once|duplicate")
})

testthat::test_that("wrong event direction requires explicit declaration", {
  cohort <- mm_adv_fixture()$cohort
  cohort$event_label <- ifelse(cohort$event == 1, "case", "control")
  testthat::expect_error(mysterymodel::mm_project(
    "direction", "event_label", "age", cohort = cohort
  ), "positive_class|event")
  correct <- mysterymodel::mm_project(
    "direction", "event_label", "age", cohort = cohort,
    positive_class = "case"
  )
  testthat::expect_identical(correct$positive_class, "case")
})

testthat::test_that("prediction refuses unknown categorical levels", {
  fixture <- mm_adv_fixture()
  profile <- mm_adv_profiles(fixture, n = 1L)
  profile$sex <- "not_an_observed_category"
  testthat::expect_error(
    mysterymodel::mm_predict(fixture$fit, profile),
    "never saw|level|Known"
  )
})

testthat::test_that("missing predictor does not become risk zero", {
  fixture <- mm_adv_fixture()
  profiles <- mm_adv_profiles(fixture)
  profiles$age[2L] <- NA_real_
  testthat::expect_error(mysterymodel::mm_predict(
    fixture$fit, profiles
  ), "missing")
  scored <- mysterymodel::mm_predict(
    fixture$fit, profiles, on_missing = "na"
  )
  testthat::expect_true(is.na(scored$.pred[2L]))
  testthat::expect_true(all(is.finite(scored$.pred[-2L])))
  testthat::expect_identical(nrow(scored), nrow(profiles))
})

testthat::test_that("out-of-range predictors are marked as extrapolation", {
  fixture <- mm_adv_fixture()
  profiles <- mm_adv_profiles(fixture)
  profiles$age[1L] <- max(fixture$cohort$age, na.rm = TRUE) + 25
  scored <- mysterymodel::mm_predict(fixture$fit, profiles)
  testthat::expect_true(scored$.extrapolated[1L])
  testthat::expect_true(is.finite(scored$.pred[1L]))
  testthat::expect_true(scored$.pred[1L] >= 0 && scored$.pred[1L] <= 1)
})

testthat::test_that("model formula cannot retain complete raw cohort", {
  fixture <- mm_adv_fixture()
  environment_used <- environment(fixture$fit$formula)
  testthat::expect_identical(environment_used, baseenv())
  testthat::expect_false(exists("cohort", envir = environment_used,
                                inherits = FALSE))
})
