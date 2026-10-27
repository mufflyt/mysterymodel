test_that("the cohort is reproducible", {
  a <- cp_synthetic_cohort(n = 500, seed = 1978)
  b <- cp_synthetic_cohort(n = 500, seed = 1978)
  expect_identical(a, b)
})

test_that("realised prevalence sits within sampling error of the target", {
  # The intercept is solved so the EXPECTED prevalence meets the target. The
  # realised one is a binomial draw around it, so the bound is computed from
  # the binomial standard error rather than picked to fit.
  n <- 500
  target <- 0.11
  se <- sqrt(target * (1 - target) / n)
  got <- mean(cp_synthetic_cohort(n = n, prevalence = target,
                                  seed = 1978)$event)
  expect_lt(abs(got - target), 4 * se)
})

test_that("a different target moves the prevalence with it", {
  low <- mean(cp_synthetic_cohort(n = 1000, prevalence = 0.05,
                                  seed = 5)$event)
  high <- mean(cp_synthetic_cohort(n = 1000, prevalence = 0.40,
                                   seed = 5)$event)
  expect_lt(low, 0.10)
  expect_gt(high, 0.33)
})

test_that("the cohort carries its own truth", {
  d <- cp_synthetic_cohort(n = 200, seed = 1)
  truth <- attr(d, "truth")
  expect_true(all(c("age_sq", "bmi", "uti_by_male") %in%
                    names(truth$coefficients)))
  expect_true(nzchar(truth$formula))
})

test_that("repeat visits exist, so clustering has something to cluster", {
  d <- cp_synthetic_cohort(n = 500, repeat_frac = 0.1, seed = 3)
  expect_lt(length(unique(d$pid)), nrow(d))
})

test_that("the generator does not disturb the ambient random stream", {
  set.seed(99)
  before <- stats::runif(1)
  set.seed(99)
  invisible(cp_synthetic_cohort(n = 50, seed = 7))
  expect_identical(stats::runif(1), before)
})
