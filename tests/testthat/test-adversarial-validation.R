testthat::test_that("invalid bootstrap B does not consume RNG", {
  fixture <- mm_adv_fixture(n = 300L)
  invalid <- list(0L, -1L, 2.7, NA_real_, NaN, Inf,
                  "20", numeric(0), c(2L, 3L))
  for (candidate in invalid) {
    set.seed(771L)
    before <- .Random.seed
    testthat::expect_error(mysterymodel::mm_validate(
      fixture$fit, fixture$cohort, B = candidate
    ))
    testthat::expect_identical(.Random.seed, before)
  }
})

testthat::test_that("apparent calibration does not masquerade as validated", {
  fixture <- mm_adv_fixture(n = 400L)
  validation <- suppressWarnings(mysterymodel::mm_validate(
    fixture$fit, fixture$cohort, B = 8L
  ))
  tab <- validation$metrics
  testthat::expect_true("basis" %in% names(tab))
  apparent <- tab[tab$basis == "apparent", , drop = FALSE]
  testthat::expect_equal(nrow(apparent), 1L)
  testthat::expect_true(is.na(apparent$cal_intercept))
  testthat::expect_true(is.na(apparent$cal_slope))
  corrected <- tab[grepl("bootstrap", tab$basis), , drop = FALSE]
  testthat::expect_true(nrow(corrected) >= 1L)
  testthat::expect_true(all(is.na(corrected$c_lower)))
  testthat::expect_true(all(is.na(corrected$c_upper)))
})

testthat::test_that("corrected intervals cannot borrow apparent intervals", {
  fixture <- mm_adv_fixture(n = 400L)
  validation <- suppressWarnings(mysterymodel::mm_validate(
    fixture$fit, fixture$cohort, B = 8L
  ))
  corrected <- validation$metrics[
    grepl("bootstrap", validation$metrics$basis), , drop = FALSE
  ]
  testthat::expect_true(all(is.na(corrected$c_lower)))
  testthat::expect_true(all(is.na(corrected$c_upper)))
  testthat::expect_true(all(grepl("interval|bootstrap",
                                   corrected$note, ignore.case = TRUE)))
})
