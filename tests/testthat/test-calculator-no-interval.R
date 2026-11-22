# Review finding D-1, resolved by owner decision: the patient-facing calculator
# must not display an uncertainty range beside an individual risk estimate.
#
# The interval mm_predict() computes is PARAMETER uncertainty on the
# probability scale. Printed beside one person's risk it reads as PREDICTION
# uncertainty, which is wider and which this package does not compute. The
# authorised resolution was to withhold it from the display, keep it in the
# statistical object, change no fitted model and substitute no other interval.
#
# This file is the guard against silent reintroduction. It asserts the five
# things the decision asked for, and it reads the rendered markup rather than
# the source, so a reinstated bar, span or style fails here even if it is
# written differently from the version that was removed.

cal_fixture <- function(n = 400, seed = 1978) {
  co <- mm_synthetic_cohort(n = n, prevalence = 0.15, seed = seed)
  pr <- mm_project(slug = "d1", outcome = "event",
                   predictors = c("age", "bmi", "sex"),
                   positive_class = "1", cohort = co)
  list(model = suppressWarnings(mm_model(pr, co)), cohort = co)
}

# Render the markup from the builders that produce it, rather than from the
# whole app: the explainer and the comparison list are built by helpers, and
# the point-estimate slots live in the panel. Reading rendered HTML means a
# reinstated interval fails here however it is written.
as_html <- function(x) paste(as.character(x), collapse = " ")

disclaimer_html <- function(audience) {
  as_html(mm_calculator_disclaimer(subject = "patient", audience = audience))
}

test_that("1. the point estimate is still displayed", {
  f <- cal_fixture()
  p <- mm_predict(f$model, f$cohort[1, , drop = FALSE], interval = TRUE)
  band <- mm_calculator_band(p$.pred[1], 0.1, "worse", "patient",
                             "clinician", NULL, 3L)
  gauge <- as_html(mm_calculator_gauge(p$.pred[1], band, 0.1))
  # the gauge still points at the estimate: the needle angle encodes it
  expect_match(gauge, "gauge-needle", fixed = TRUE)
  expect_match(gauge, "rotate(", fixed = TRUE)
  # and the slot the figure is written into is still in the panel
  src <- paste(readLines(testthat::test_path("..", "..", "R", "calculator.R"),
                         warn = FALSE), collapse = "\n")
  skip_if(!nzchar(src), "source not reachable from the installed package")
  expect_true(grepl('textOutput("probability"', src, fixed = TRUE))
  expect_true(grepl("output$probability", src, fixed = TRUE))
})

test_that("2. no interval is displayed beside the estimate", {
  # The source itself: the renderer, the slot, the markup classes and the
  # styles that supported them are all gone. Checked in the source because
  # these are the exact affordances whose return the decision forbids.
  src <- paste(readLines(testthat::test_path("..", "..", "R", "calculator.R"),
                         warn = FALSE), collapse = "\n")
  skip_if(!nzchar(src), "source not reachable from the installed package")
  # the code that produced them, not prose mentioning them: the comments
  # recording the removal necessarily name what was removed
  for (gone in c("output$interval <-",
                 'class = "ci-display"',
                 'class = "compare-ci"',
                 'class = "compare-ci-text"',
                 'textOutput("interval"',
                 "95%% CI")) {
    expect_false(grepl(gone, src, fixed = TRUE), info = gone)
  }
  # and nothing renders a range from the record's bounds
  expect_false(grepl("100 * r$lower", src, fixed = TRUE))
  expect_false(grepl("100 * r$upper", src, fixed = TRUE))
})

test_that("3. the underlying statistical information remains available", {
  f <- cal_fixture()
  # mm_predict() still computes and returns the interval: the decision was to
  # withhold it from a display, not to stop computing it
  p <- mm_predict(f$model, f$cohort[1, , drop = FALSE], interval = TRUE)
  expect_true(all(c(".pred", ".lower", ".upper") %in% names(p)))
  expect_false(is.na(p$.lower[1]))
  expect_false(is.na(p$.upper[1]))
  expect_lt(p$.lower[1], p$.pred[1])
  expect_gt(p$.upper[1], p$.pred[1])
  # and the comparison helper still accepts records carrying it, so the saved
  # records keep the numbers even though no bar is drawn from them
  rec <- list(list(values = f$cohort[1, , drop = FALSE], pred = p$.pred[1],
                   lower = p$.lower[1], upper = p$.upper[1],
                   extrapolated = FALSE))
  out <- as_html(mm_calculator_comparison(rec, threshold = 0.1,
                                          higher_is = "worse",
                                          subject = "patient"))
  expect_match(out, "compare-dot", fixed = TRUE)
  expect_no_match(out, "compare-ci", fixed = TRUE)
})

test_that("4. the documentation distinguishes the three uncertainties", {
  for (aud in c("clinician", "self")) {
    expect_match(disclaimer_html(aud), "Before you use this", fixed = TRUE)
  }
  clin <- disclaimer_html("clinician")
  # named explicitly, because the point is that they are not interchangeable
  expect_match(clin, "PARAMETER uncertainty", fixed = TRUE)
  expect_match(clin, "ESTIMATED RISK", fixed = TRUE)
  expect_match(clin, "PREDICTION uncertainty", fixed = TRUE)
  # the patient-facing wording says a range was removed rather than leaving
  # its absence unexplained
  expect_match(disclaimer_html("self"), "no range beside it", fixed = TRUE)
})

test_that("5. existing validated predictions are numerically unchanged", {
  # The decision explicitly did not authorise touching fitted models or point
  # estimates. These are the same invariants test-prediction-paths-agree.R
  # asserts, re-asserted here so that a change made in the name of D-1 cannot
  # move a number.
  f <- cal_fixture()
  m <- f$model
  from_predict <- mm_predict(m, f$cohort)$.pred
  from_fitted <- stats::fitted(m)
  expect_identical(max(abs(from_predict[seq_along(from_fitted)] - from_fitted)), 0)
  expect_identical(stats::nobs(m), m$n_dev)

  v <- mm_validate(m, f$cohort, B = 25)
  app <- v$metrics[v$metrics$basis == "apparent", ]
  expect_identical(as.numeric(app$n[1]), as.numeric(stats::nobs(m)))
  expect_true(app$c_stat[1] > 0 && app$c_stat[1] <= 1)
})
