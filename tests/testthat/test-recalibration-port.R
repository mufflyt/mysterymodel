# Tests for portable nomogram-final recalibration helpers.
testthat::test_that("recalibration preserves the ranking", {
  linear <- c(-4, -2, -0.1, 0.5, 2)
  changed <- mysterymodel::mm_recal_apply(
    linear, a = 0.8, b = 0.75
  )
  testthat::expect_true(all(diff(changed) > 0))
  testthat::expect_equal(
    order(changed), order(stats::plogis(linear))
  )
  testthat::expect_error(
    mysterymodel::mm_recal_apply(linear, a = 0, b = -1),
    "positive slope"
  )
})
testthat::test_that("intercept-only recalibration changes calibration", {
  linear <- rep(c(-1, 0, 1), each = 100)
  observed <- rep(c(0, 1, 0, 1, 1), length.out = length(linear))
  rec <- mysterymodel::mm_recal_intercept(linear, observed)
  testthat::expect_true(is.finite(rec$a))
  testthat::expect_true(is.finite(rec$se))
  testthat::expect_identical(rec$n, length(linear))
  testthat::expect_equal(
    mean(mysterymodel::mm_recal_apply(linear, rec$a)),
    mean(observed),
    tolerance = 1e-6
  )
})
testthat::test_that("Rubin pooling includes between-imputation variance", {
  pooled <- mysterymodel::mm_rubin(c(0, 1), c(0.2, 0.2))
  testthat::expect_equal(pooled$within, 0.04)
  testthat::expect_equal(pooled$between, 0.5)
  testthat::expect_equal(pooled$se, sqrt(0.04 + 1.5 * 0.5))
  testthat::expect_identical(pooled$m, 2L)
  testthat::expect_error(
    mysterymodel::mm_rubin(c(1, 2), c(0.1)),
    "standard errors"
  )
})
testthat::test_that("subgroup recalibration respects minimum sample size", {
  linear <- rep(c(-1, 0, 1), length.out = 100)
  observed <- rep(c(0, 1), 50)
  grouped <- mysterymodel::mm_recal_by(
    linear, observed, rep(c("a", "b"), each = 50),
    min_n = 60
  )
  testthat::expect_true(all(is.na(grouped$a)))
  testthat::expect_true(all(grouped$n == 50))
})
testthat::test_that("closed updating declines impossible input", {
  testthat::expect_error(
    mysterymodel::mm_update_test(
      lp = rep(0, 19), y = rep(c(0, 1), length.out = 19)
    ), "fewer than 20"
  )
  testthat::expect_error(
    mysterymodel::mm_update_test(
      lp = rep(0, 30), y = rep(1, 30)
    ), "one level"
  )
})
testthat::test_that("collinearity diagnostics flag numeric copies", {
  predictors <- data.frame(
    a = seq_len(30), b = seq_len(30), c = rep(c(0, 1), 15)
  )
  pairs <- mysterymodel::mm_cor_pairs(predictors, max = 0.99)
  testthat::expect_true(any(
    (pairs$a == "a" & pairs$b == "b") |
    (pairs$a == "b" & pairs$b == "a")
  ))
  testthat::expect_true(any(abs(pairs$rho) >= 0.99))
})
