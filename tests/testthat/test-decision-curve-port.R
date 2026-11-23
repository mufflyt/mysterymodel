# Adversarial decision-curve tests for the portable implementation.
testthat::test_that("factor outcome is not silently treated as all zero", {
  observed <- factor(c("No", "Yes", "No", "Yes", "Yes", "No"))
  predicted <- c(0.1, 0.9, 0.3, 0.8, 0.65, 0.2)
  curve <- mysterymodel::mm_decision_curve(
    observed, predicted, thresholds = c(0.2, 0.5), positive = "Yes"
  )
  testthat::expect_equal(curve$n, c(6L, 6L))
  testthat::expect_equal(curve$prevalence, c(0.5, 0.5))
  testthat::expect_true(any(curve$net_benefit_model > 0))
})
testthat::test_that("NA predictions are excluded and counted", {
  observed <- c(0, 1, 0, 1, 0, 1)
  predicted <- c(0.1, 0.8, NA_real_, 0.9, 0.2, 0.7)
  curve <- mysterymodel::mm_decision_curve(
    observed, predicted, thresholds = 0.5
  )
  testthat::expect_identical(curve$n, 5L)
  testthat::expect_identical(curve$n_dropped, 1L)
  testthat::expect_equal(curve$net_benefit_model, 3 / 5)
})
testthat::test_that("treatment threshold one is rejected", {
  testthat::expect_error(
    mysterymodel::mm_decision_curve(
      c(0, 1), c(0.1, 0.9), thresholds = 1
    ), "thresholds"
  )
  testthat::expect_error(
    mysterymodel::mm_decision_curve(
      c(0, 1), c(0.1, 0.9), thresholds = Inf
    ), "thresholds"
  )
})
testthat::test_that("invalid predicted probabilities are rejected", {
  for (bad in c(-0.01, 1.01, Inf, -Inf)) {
    testthat::expect_error(
      mysterymodel::mm_decision_curve(
        c(0, 1), c(bad, 0.9), thresholds = 0.5
      ), "probabilities"
    )
  }
})
testthat::test_that("treat-all and treat-none have exact references", {
  observed <- c(0, 1, 0, 1)
  predicted <- c(0.2, 0.8, 0.4, 0.9)
  curve <- mysterymodel::mm_decision_curve(
    observed, predicted, thresholds = 0.5
  )
  testthat::expect_equal(curve$net_benefit_none, 0)
  testthat::expect_equal(curve$net_benefit_all, 0)
  testthat::expect_equal(curve$net_benefit_model, 0.5)
})

testthat::test_that("factor event direction cannot be guessed", {
  testthat::expect_error(
    mysterymodel::mm_decision_curve(
      factor(c("case", "control", "case", "control")),
      c(0.8, 0.2, 0.7, 0.3),
      thresholds = 0.5
    ), "explicit")
  testthat::expect_error(
    mysterymodel::mm_decision_curve(
      c(0, 1), c(0.1, 0.9), thresholds = 0.5,
      positive = 0
    ), "only for factor")
})
