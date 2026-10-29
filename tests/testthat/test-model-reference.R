# Fixture 1 of the specification's suite: a complete binary cohort whose
# predictions are checked against the engine rather than against themselves.

fixture <- function(n = 400, seed = 1978, ...) {
  cohort <- cp_synthetic_cohort(n = n, seed = seed)
  project <- cp_project("uds", "event",
                        c("age", "bmi", "sex", "prior_uti"),
                        cohort = cohort, split_var = "year",
                        split_at = 2023, ...)
  list(cohort = cohort, project = project)
}

test_that("an interaction without its main effects is refused", {
  f <- fixture()
  thin <- cp_project("uds", "event", c("age", "sex"), cohort = f$cohort)
  expect_error(
    cp_model(thin, f$cohort, interactions = list(c("prior_uti", "sex"))),
    "needs its main effect")
})

test_that("nonlinear terms must be predictors", {
  f <- fixture()
  expect_error(cp_model(f$project, f$cohort, nonlinear = "weight"),
               "not predictors")
})

test_that("the model keeps x and y, which validation needs", {
  f <- fixture()
  m <- suppressWarnings(cp_model(f$project, f$cohort, nonlinear = "age"))
  expect_false(is.null(m$fit$x))
  expect_false(is.null(m$fit$y))
})

test_that("the model stores no copy of the cohort", {
  f <- fixture()
  m <- suppressWarnings(cp_model(f$project, f$cohort, nonlinear = "age"))
  stored <- vapply(m, function(el) {
    is.data.frame(el) && nrow(el) > 1L
  }, logical(1))
  expect_false(any(stored))
})

test_that("cp_predict reproduces rms::predict exactly", {
  f <- fixture()
  m <- suppressWarnings(cp_model(f$project, f$cohort, nonlinear = "age",
                interactions = list(c("prior_uti", "sex"))))
  mine <- cp_predict(m, f$cohort)$.pred
  old <- options(datadist = m$datadist)
  on.exit(options(old), add = TRUE)
  theirs <- as.numeric(stats::predict(m$fit, newdata = f$cohort,
                                      type = "fitted"))
  expect_equal(mine, theirs, tolerance = 1e-12)
})

test_that("a level the model never saw is refused by name", {
  f <- fixture()
  m <- suppressWarnings(cp_model(f$project, f$cohort))
  odd <- f$cohort[1:3, ]
  odd$sex <- "unrecorded"
  expect_error(cp_predict(m, odd), "unrecorded")
})

test_that("a missing predictor is refused, or returned as NA on request", {
  f <- fixture()
  m <- suppressWarnings(cp_model(f$project, f$cohort))
  gap <- f$cohort[1:4, ]
  gap$bmi[2] <- NA
  expect_error(cp_predict(m, gap), "missing predictor")
  out <- cp_predict(m, gap, on_missing = "na")
  expect_true(is.na(out$.pred[2]))
  expect_false(any(is.na(out$.pred[-2])))
})

test_that("extrapolation is labelled rather than hidden", {
  f <- fixture()
  m <- suppressWarnings(cp_model(f$project, f$cohort))
  far <- f$cohort[1:2, ]
  far$age <- c(5, 200)
  expect_true(all(cp_predict(m, far)$.extrapolated))
})

test_that("a split row with a missing split variable is not dropped", {
  f <- fixture()
  broken <- f$cohort
  broken$year[1] <- NA
  expect_error(cp_model(f$project, broken), "neither side of the split")
})
