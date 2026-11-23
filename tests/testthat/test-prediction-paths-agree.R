# Workstream D4: the prediction paths must agree where their documented
# outputs represent the same estimand.
#
# mm_predict() is the reference. fitted() is new (R/accessors.R) and must not
# have introduced a second, subtly different scoring route. mm_nomogram()
# carries its own read-back check, and this pins the tolerance it reports so
# that a future change cannot quietly loosen it.
#
# mm_calculator() is NOT compared numerically here: it scores through
# mm_predict() directly (R/calculator.R:121), so it agrees by construction
# rather than by coincidence. What it does with the result is review finding
# D-1, which is about what the interval is labelled, not what it equals.

test_that("fitted() and mm_predict() are the same number, not merely close", {
  co <- mm_synthetic_cohort(n = 600, prevalence = 0.15, seed = 1978)
  pr <- mm_project(slug = "paths", outcome = "event",
                   predictors = c("age", "bmi", "sex"),
                   positive_class = "1", cohort = co)
  m <- suppressWarnings(mm_model(pr, co))

  from_predict <- mm_predict(m, co)$.pred
  from_fitted <- stats::fitted(m)
  expect_length(from_fitted, m$n_dev)
  # exact, because both resolve to the same rms scoring call. A tolerance here
  # would hide a second implementation drifting from the first.
  expect_identical(max(abs(from_predict[seq_along(from_fitted)] - from_fitted)), 0)
})

test_that("the link scale and the response scale are one logistic apart", {
  co <- mm_synthetic_cohort(n = 300, prevalence = 0.2, seed = 7)
  pr <- mm_project(slug = "paths2", outcome = "event",
                   predictors = c("age", "bmi", "sex"),
                   positive_class = "1", cohort = co)
  m <- suppressWarnings(mm_model(pr, co))
  expect_equal(as.numeric(stats::fitted(m)),
               as.numeric(stats::plogis(stats::fitted(m, scale = "link"))),
               tolerance = 1e-12)
})

test_that("the nomogram still reproduces the model it was drawn from", {
  co <- mm_synthetic_cohort(n = 600, prevalence = 0.15, seed = 1978)
  pr <- mm_project(slug = "paths3", outcome = "event",
                   predictors = c("age", "bmi", "sex"),
                   positive_class = "1", cohort = co)
  m <- suppressWarnings(mm_model(pr, co))
  nom <- suppressWarnings(mm_nomogram(m, out_dir = withr::local_tempdir()))

  # the package's own invariant: the drawn sheet, read back by summing points
  # and interpolating the printed axis, must agree with mm_predict()
  expect_lt(nom$worst_disagreement, nom$tolerance)
  expect_identical(nom$tolerance, 1e-06)
  # a model with no splines reads exactly between ticks, which is the claim
  # DEC-007 makes about the bound being derived rather than sampled
  expect_lt(nom$reading_error, 1e-10)
  expect_gt(nom$profiles_checked, 0L)
})
