
test_that("an interval is offered, and asking for it does not move the estimate", {
  cohort <- mm_synthetic_cohort(n = 400, seed = 2)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  rows <- cohort[1:20, ]

  plain <- mm_predict(fit, rows)
  with_ci <- mm_predict(fit, rows, interval = TRUE)

  # The fitted value is what the rest of the package is checked against, the
  # nomogram to machine precision among it, so an interval is computed beside
  # it and never instead of it.
  expect_identical(plain$.pred, with_ci$.pred)
  expect_identical(names(plain), c(".pred", ".extrapolated"))
  expect_identical(names(with_ci),
                   c(".pred", ".extrapolated", ".lower", ".upper"))

  expect_true(all(with_ci$.lower < with_ci$.pred))
  expect_true(all(with_ci$.pred < with_ci$.upper))
  expect_true(all(with_ci$.lower > 0 & with_ci$.upper < 1))

  # Wider coverage, wider interval.
  wide <- mm_predict(fit, rows, interval = TRUE, level = 0.99)
  expect_true(all(wide$.lower < with_ci$.lower))
  expect_true(all(wide$.upper > with_ci$.upper))

  expect_error(mm_predict(fit, rows, interval = TRUE, level = 1),
               "between 0 and 1")
  expect_error(mm_predict(fit, rows, interval = TRUE, level = c(0.9, 0.95)),
               "single coverage")
})

test_that("a row that cannot be scored gets no interval either", {
  cohort <- mm_synthetic_cohort(n = 400, seed = 2)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  rows <- cohort[1:4, ]
  rows$bmi[2] <- NA_real_

  out <- mm_predict(fit, rows, on_missing = "na", interval = TRUE)
  expect_true(is.na(out$.pred[2]))
  expect_true(is.na(out$.lower[2]))
  expect_true(is.na(out$.upper[2]))
  expect_false(any(is.na(out$.lower[-2])))
})

test_that("the interval is on the probability scale, not a symmetric band", {
  # plogis of the limits, not the limits of plogis plus or minus. A symmetric
  # band on the probability scale runs past 0 and 1 for a low-risk patient,
  # which is how a calculator comes to quote a negative risk.
  cohort <- mm_synthetic_cohort(n = 400, seed = 2, prevalence = 0.03)
  project <- mm_project("uds", "event", c("age", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  out <- mm_predict(fit, cohort[1:50, ], interval = TRUE)
  expect_true(all(out$.lower > 0))
  # Asymmetric about the estimate, because the transform is.
  gap_low <- out$.pred - out$.lower
  gap_high <- out$.upper - out$.pred
  expect_true(all(gap_high > gap_low))
})
