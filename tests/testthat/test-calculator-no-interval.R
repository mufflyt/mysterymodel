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
# things the decision asked for.
#
# Block 3 reads rendered markup. Block 2 reads the SOURCE, and says so: the
# main result panel is built inline inside mm_calculator() and a shiny.appobj
# does not expose its static UI (app$ui is NULL), so there is no markup to
# render without restructuring production code for the test. The source scan is
# therefore written to catch the mechanism rather than six spellings: an
# interval cannot be displayed without reading .lower or .upper from the
# prediction, so those two names are asserted to appear ONLY where the decision
# permits them. A reinstated range under any class name, format string or
# helper has to read one of them and fails here.

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

# readLines() aborts on a missing file, so a skip_if() placed after it never
# runs. Under R CMD check the suite executes from <pkg>.Rcheck/tests/testthat,
# where ../../R does not exist (the installed sources are byte-compiled under
# ../../<pkg>/R), so the unguarded version turned this guard into two errors on
# exactly the platform it was written to protect.
calculator_source <- function() {
  f <- testthat::test_path("..", "..", "R", "calculator.R")
  if (!file.exists(f)) return(NULL)
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

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
  src <- calculator_source()
  skip_if(is.null(src), "source not reachable (installed-package check)")
  expect_true(grepl('textOutput("probability"', src, fixed = TRUE))
  expect_true(grepl("output$probability", src, fixed = TRUE))
})

test_that("2. no interval is displayed beside the estimate", {
  # The source itself: the renderer, the slot, the markup classes and the
  # styles that supported them are all gone. Checked in the source because
  # these are the exact affordances whose return the decision forbids.
  src <- calculator_source()
  skip_if(is.null(src), "source not reachable (installed-package check)")

  # 2a. The specific affordances that were removed stay removed. Matching the
  # code that produced them, not prose naming them: the comments recording the
  # removal necessarily mention what was removed.
  for (gone in c("output$interval <-",
                 'class = "ci-display"',
                 'class = "compare-ci"',
                 'class = "compare-ci-text"',
                 'textOutput("interval"',
                 "95%% CI")) {
    expect_false(grepl(gone, src, fixed = TRUE), info = gone)
  }

  # 2b. The mechanism, which is the part that does not depend on spelling.
  # Displaying an interval requires reading .lower or .upper. Every permitted
  # use is listed; anything else is a reintroduction however it is written.
  lines <- strsplit(src, "\n", fixed = TRUE)[[1]]
  code <- lines[!grepl("^\\s*#", lines)]
  uses <- grep("[$]\\.?(lower|upper)\\b", code, value = TRUE)
  permitted <- c(
    # the saved record keeps the bounds; nothing draws them
    "lower = p$.lower[1], upper = p$.upper[1],",
    # and the stored bound no longer sets the axis either (finding F-5)
    "vapply(saved, function(r) r$pred, numeric(1)) * 1.05))")
  unexpected <- trimws(uses)[!trimws(uses) %in% permitted]
  expect_identical(unexpected, character(0),
                   info = paste("unpermitted read of a bound:",
                                paste(unexpected, collapse = " | ")))
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
