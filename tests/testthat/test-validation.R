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
  # And it says how many resamples rms actually fitted, and on what unit,
  # rather than restating the number that was requested.
  expect_match(boot$note, "20 of 20 resample\\(s\\) fitted")
  expect_match(boot$note, "Resampled by row")
})

test_that("apparent performance is at least as good as corrected", {
  f <- val_fixture()
  v <- mm_validate(f$model, f$cohort, B = 40)
  app <- v$metrics$c_stat[v$metrics$basis == "apparent"]
  cor <- v$metrics$c_stat[v$metrics$basis == "bootstrap, fixed model"]
  expect_gte(app, cor)
})

test_that("apparent calibration is an identity, so it is not reported", {
  f <- val_fixture()
  v <- mm_validate(f$model, f$cohort, B = 20)

  # The quantities exist and are exactly 0 and 1, which is the point: the
  # score equations of an unpenalized fit scored on its own rows force them.
  # This half of the test records the fact.
  # Read off the fit itself, so these are exactly the rows it was estimated
  # on. The identity holds there and nowhere else: the held-out rows below
  # give a slope of their own.
  y <- as.integer(f$model$fit$y)
  lp <- as.numeric(f$model$fit$linear.predictors)
  expect_equal(unname(stats::coef(
    stats::glm(y ~ 1, family = stats::binomial(), offset = lp))[1]), 0,
    tolerance = 1e-6)
  expect_equal(unname(stats::coef(
    stats::glm(y ~ lp, family = stats::binomial()))[2]), 1,
    tolerance = 1e-6)

  # And this half records that they are withheld rather than printed, because
  # beside a held-out slope they would read as the model being well
  # calibrated, which is the one thing they cannot show.
  app <- v$metrics[v$metrics$basis == "apparent", ]
  expect_true(is.na(app$cal_slope))
  expect_true(is.na(app$cal_intercept))
  expect_match(app$note, "describe the estimator and not the model")

  # The rows where calibration is estimable still carry it.
  held <- v$metrics[v$metrics$basis == "held out", ]
  expect_false(is.na(held$cal_slope))
  expect_false(is.na(v$metrics$cal_slope[
    v$metrics$basis == "bootstrap, fixed model"]))
})

test_that("a calibration that is not the identity is still reported", {
  # Detected rather than assumed, so a fitting method that does not force the
  # identity has its apparent calibration reported as the estimate it is.
  deliberate <- data.frame(
    basis = "apparent", n = 100L, events = 20L,
    c_stat = 0.7, c_lower = 0.6, c_upper = 0.8,
    cal_intercept = 0.4, cal_slope = 0.65,
    brier = 0.1, brier_scaled = 0.2, note = "x",
    stringsAsFactors = FALSE)
  kept <- mysterymodel:::mm_withhold_identity_calibration(deliberate)
  expect_equal(kept$cal_intercept, 0.4)
  expect_equal(kept$cal_slope, 0.65)
  expect_equal(kept$note, "x")
})

test_that("discrimination comes with an interval where it is estimable", {
  f <- val_fixture()
  v <- mm_validate(f$model, f$cohort, B = 20)
  scored <- v$metrics[!is.na(v$metrics$c_lower), ]
  expect_true(all(scored$c_lower < scored$c_stat))
  expect_true(all(scored$c_stat < scored$c_upper))
})

test_that("B must be a whole number of at least one resample", {
  f <- val_fixture()
  expect_error(mm_validate(f$model, f$cohort, B = 0),
               "At least one resample")
})

test_that("both bootstraps read one four-fifths threshold", {
  expect_equal(mysterymodel:::mm_min_resamples(100), 80)
  expect_equal(mysterymodel:::mm_min_resamples(25), 20)
  # Not a round multiple: the threshold rounds up, so 0.8 is a floor and not
  # an invitation to report 79 of 99 as adequate.
  expect_equal(mysterymodel:::mm_min_resamples(99), 80)

  f <- val_fixture()
  v <- suppressWarnings(mm_validate(f$model, f$cohort, B = 10,
                                    full_process = TRUE))
  expect_equal(v$full_process_detail$B, 10L)
  expect_true(v$fixed_model$adequate)
  expect_true(v$full_process_detail$adequate)
})

test_that("the scaled Brier reference stays the development cohort's", {
  expect_equal(mysterymodel:::mm_no_information(0.2), 0.16)
  expect_equal(mysterymodel:::mm_no_information(0), 0)
  expect_equal(mysterymodel:::mm_no_information(1), 0)

  # Computed here from the fitted rows, not read back off the object, so this
  # fails if any basis is ever scaled by its own prevalence instead.
  f <- val_fixture()
  v <- suppressWarnings(mm_validate(f$model, f$cohort, B = 10,
                                    full_process = TRUE))
  dev <- f$cohort[f$cohort$year < 2023, , drop = FALSE]
  rate <- mean(mysterymodel:::mm_event_indicator(dev$event, NULL))
  reference <- rate * (1 - rate)

  scored <- v$metrics[!is.na(v$metrics$brier_ref), ]
  expect_gt(nrow(scored), 1L)
  expect_true(all(scored$brier_ref == reference))
  expect_equal(v$full_process_detail$no_information_brier, reference)

  # The held-out rows have a prevalence of their own, and it is not the one
  # the column is scaled by, which is the condition the note describes.
  held <- v$metrics[v$metrics$basis == "held out", ]
  expect_equal(held$brier_scaled, 1 - held$brier / reference)
  expect_match(held$note, "not this sample's own")
})

test_that("the resample count is checked against its own name", {
  # The message names `B` because that is what every caller writes. It was
  # parameterised for a second caller that never arrived.
  expect_named(formals(mysterymodel:::mm_check_resamples), "B")
  for (bad in list(0, -1, 2.7, NA_integer_, NaN, Inf, "20", c(10, 10),
                   integer(0), TRUE)) {
    expect_error(mysterymodel:::mm_check_resamples(bad), "`B`")
  }
  expect_identical(mysterymodel:::mm_check_resamples(200), 200L)
  expect_identical(mysterymodel:::mm_check_resamples(200.0), 200L)

  # Refused before any seed is set, so a rejected call leaves the caller's
  # random-number state as it found it.
  set.seed(42)
  before <- .Random.seed
  expect_error(mysterymodel:::mm_check_resamples(0))
  expect_identical(.Random.seed, before)
})
