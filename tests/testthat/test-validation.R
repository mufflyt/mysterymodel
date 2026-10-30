val_fixture <- function(n = 400, seed = 1978) {
  cohort <- mm_synthetic_cohort(n = n, seed = seed)
  project <- mm_project("uds", "event",
                        c("age", "bmi", "sex", "prior_uti"),
                        cohort = cohort, split_var = "year",
                        split_at = 2023)
  # Small for speed; the adequacy warning is tested in
  # test-sample-size.R, not here.
  list(cohort = cohort,
       model = suppressWarnings(mm_model(project, cohort,
                                         nonlinear = "age")))
}

test_that("every basis is reported separately and labelled", {
  f <- val_fixture()
  v <- mm_validate(f$model, f$cohort, B = 20)
  expect_setequal(v$metrics$basis,
                  c("apparent", "bootstrap, fixed model", "held out"))
  expect_true(all(nzchar(v$metrics$note)))
})

test_that("the bootstrap does not claim to validate a strategy", {
  # rms::validate refits one formula. It does not repeat imputation,
  # selection or tuning, so it must not be presented as full-process.
  f <- val_fixture()
  v <- mm_validate(f$model, f$cohort, B = 20)
  expect_false(v$full_process)
  boot <- v$metrics[v$metrics$basis == "bootstrap, fixed model", ]
  expect_match(boot$note, "does not re-derive")
  expect_match(boot$note, "resamples rows even when a cluster is declared")
})

test_that("apparent performance is at least as good as corrected", {
  f <- val_fixture()
  v <- mm_validate(f$model, f$cohort, B = 40)
  app <- v$metrics$c_stat[v$metrics$basis == "apparent"]
  cor <- v$metrics$c_stat[v$metrics$basis == "bootstrap, fixed model"]
  expect_gte(app, cor)
})

test_that("apparent calibration slope is one by construction", {
  f <- val_fixture()
  v <- mm_validate(f$model, f$cohort, B = 20)
  app <- v$metrics[v$metrics$basis == "apparent", ]
  expect_equal(app$cal_slope, 1, tolerance = 1e-6)
  expect_equal(app$cal_intercept, 0, tolerance = 1e-6)
})

test_that("discrimination comes with an interval where it is estimable", {
  f <- val_fixture()
  v <- mm_validate(f$model, f$cohort, B = 20)
  scored <- v$metrics[!is.na(v$metrics$c_lower), ]
  expect_true(all(scored$c_lower < scored$c_stat))
  expect_true(all(scored$c_stat < scored$c_upper))
})

test_that("B must be a positive number of resamples", {
  f <- val_fixture()
  expect_error(mm_validate(f$model, f$cohort, B = 0), "positive")
})
