# Contract tests: they intentionally fail until accessor fixes are wired.
testthat::test_that("model accessors delegate to the stored rms fit", {
  fixture <- mm_adv_fixture()
  wrapped <- fixture$fit
  underlying <- wrapped$fit

  testthat::expect_s3_class(wrapped, "mm_model")
  testthat::expect_identical(
    names(stats::coef(wrapped)), names(stats::coef(underlying))
  )
  testthat::expect_equal(
    unname(stats::coef(wrapped)),
    unname(stats::coef(underlying)),
    tolerance = 1e-10
  )
  testthat::expect_equal(
    stats::vcov(wrapped), stats::vcov(underlying),
    tolerance = 1e-10
  )
  testthat::expect_identical(
    as.integer(stats::nobs(wrapped)), as.integer(wrapped$n_dev)
  )
  testthat::expect_identical(
    as.integer(stats::nobs(wrapped)), as.integer(length(underlying$y))
  )
  testthat::expect_true(inherits(stats::formula(wrapped), "formula"))
  testthat::expect_true(grepl(".mm_y", deparse(stats::formula(wrapped)),
                              fixed = TRUE))
  testthat::expect_true(!is.null(base::summary(wrapped)))
})

testthat::test_that("Wald intervals are reproducible from coef and vcov", {
  fit <- mm_adv_fixture()$fit
  beta <- stats::coef(fit)
  standard_error <- sqrt(diag(stats::vcov(fit)))
  z_value <- stats::qnorm(0.975)
  expected <- cbind(
    lower = beta - z_value * standard_error,
    upper = beta + z_value * standard_error
  )
  intervals <- stats::confint(fit, level = 0.95)
  testthat::expect_true(is.matrix(intervals))
  testthat::expect_identical(rownames(intervals), names(beta))
  testthat::expect_equal(unname(intervals), unname(expected),
                         tolerance = 1e-7)
  testthat::expect_true(all(intervals[, 1L] <= intervals[, 2L]))
})

testthat::test_that("confidence-level requests change interval width", {
  fit <- mm_adv_fixture()$fit
  narrow <- stats::confint(fit, level = 0.90)
  wide <- stats::confint(fit, level = 0.99)
  testthat::expect_identical(dim(narrow), dim(wide))
  testthat::expect_true(all(wide[, 1L] < narrow[, 1L]))
  testthat::expect_true(all(wide[, 2L] > narrow[, 2L]))
  testthat::expect_error(stats::confint(fit, level = 0))
  testthat::expect_error(stats::confint(fit, level = 1))
  testthat::expect_error(stats::confint(fit, level = NA_real_))
})

testthat::test_that("response fitted values are genuine probabilities", {
  fixture <- mm_adv_fixture()
  fit <- fixture$fit
  response <- stats::fitted(fit, scale = "response")
  testthat::expect_type(response, "double")
  testthat::expect_length(response, fit$n_dev)
  testthat::expect_true(all(is.finite(response)))
  testthat::expect_true(all(response >= 0 & response <= 1))
  testthat::expect_true(stats::sd(response) > 0)
  scored <- mysterymodel::mm_predict(fit, fixture$cohort)$.pred
  testthat::expect_equal(unname(response), unname(scored),
                         tolerance = 1e-7)
})

testthat::test_that("link and response scales cannot be interchanged", {
  fit <- mm_adv_fixture()$fit
  response <- stats::fitted(fit, scale = "response")
  link <- stats::fitted(fit, scale = "link")
  testthat::expect_length(response, length(link))
  testthat::expect_equal(
    response, stats::plogis(link), tolerance = 1e-7
  )
  testthat::expect_gt(max(abs(response - link)), 0.01)
  testthat::expect_error(stats::fitted(fit, scale = "bogus"))
})

testthat::test_that("residuals are not empty or silently recycled", {
  fit <- mm_adv_fixture()$fit
  residual <- stats::residuals(fit)
  testthat::expect_true(is.numeric(residual))
  testthat::expect_length(residual, fit$n_dev)
  testthat::expect_true(all(is.finite(residual)))
})

testthat::test_that("accessors reject a missing underlying fitted model", {
  fit <- mm_adv_fixture()$fit
  fit$fit <- NULL
  testthat::expect_error(stats::coef(fit))
  testthat::expect_error(stats::vcov(fit))
  testthat::expect_error(stats::fitted(fit, scale = "response"))
  testthat::expect_error(stats::confint(fit))
})

testthat::test_that("S3 dispatch is registered, not default fallback", {
  generic_names <- c("coef", "vcov", "confint", "formula", "nobs",
                     "fitted", "residuals", "summary")
  for (generic_name in generic_names) {
    registered <- utils::getS3method(
      generic_name, "mm_model", optional = TRUE
    )
    testthat::expect_true(
      is.function(registered),
      info = paste("Missing S3 registration:", generic_name)
    )
  }
})
