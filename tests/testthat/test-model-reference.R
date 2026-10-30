# Fixture 1 of the specification's suite: a complete binary cohort whose
# predictions are checked against the engine rather than against themselves.

fixture <- function(n = 400, seed = 1978, ...) {
  cohort <- mm_synthetic_cohort(n = n, seed = seed)
  project <- mm_project("uds", "event",
                        c("age", "bmi", "sex", "prior_uti"),
                        cohort = cohort, split_var = "year",
                        split_at = 2023, ...)
  list(cohort = cohort, project = project)
}

test_that("an interaction without its main effects is refused", {
  f <- fixture()
  thin <- mm_project("uds", "event", c("age", "sex"), cohort = f$cohort)
  expect_error(
    mm_model(thin, f$cohort, interactions = list(c("prior_uti", "sex"))),
    "needs its main effect")
})

test_that("nonlinear terms must be predictors", {
  f <- fixture()
  expect_error(mm_model(f$project, f$cohort, nonlinear = "weight"),
               "not predictors")
})

test_that("the model keeps x and y, which validation needs", {
  f <- fixture()
  m <- suppressWarnings(mm_model(f$project, f$cohort, nonlinear = "age"))
  expect_false(is.null(m$fit$x))
  expect_false(is.null(m$fit$y))
})

# A cohort whose patient identifiers are findable by eye if they survive into
# an object, so that the question "did anything retain them" can be answered by
# looking rather than by reasoning about what holds a reference to what.
canary_fixture <- function(n = 120, seed = 1978, ...) {
  f <- fixture(n = n, seed = seed, cluster_id = "pid", ...)
  f$cohort$pid <- sprintf("LEAK-CANARY-%05d", seq_len(nrow(f$cohort)))
  f$project <- mm_project("uds", "event",
                          c("age", "bmi", "sex", "prior_uti"),
                          cohort = f$cohort, split_var = "year",
                          split_at = 2023, cluster_id = "pid")
  f
}

canaries_in <- function(x) {
  bytes <- serialize(x, NULL)
  text <- rawToChar(bytes[bytes > 31 & bytes < 127])
  length(unique(unlist(regmatches(
    text, gregexpr("LEAK-CANARY-[0-9]{5}", text)))))
}

test_that("the canary is findable when something really does retain it", {
  f <- canary_fixture()
  # The test's own instrument, checked against a case that must fail, so a
  # silent regression cannot pass by breaking the detector instead.
  expect_equal(canaries_in(f$cohort), nrow(f$cohort))
  expect_equal(canaries_in(list(deep = list(deeper = f$cohort))),
               nrow(f$cohort))
})

test_that("a saved model carries no patient identifier", {
  f <- canary_fixture()
  m <- suppressWarnings(mm_model(f$project, f$cohort, nonlinear = "age",
                                 interactions = list(c("prior_uti", "sex"))))
  expect_equal(canaries_in(m), 0L)

  # The specific path that used to carry them: a formula keeps the environment
  # it was built in, and rms stores that environment on the fit.
  expect_false("cohort" %in% ls(environment(m$formula)))
  expect_false("cohort" %in% ls(environment(m$fit$terms)))
  expect_equal(canaries_in(m$fit$terms), 0L)
  expect_equal(canaries_in(m$fit$sformula), 0L)
})

test_that("neither does a saved validation or a saved nomogram", {
  f <- canary_fixture()
  m <- suppressWarnings(mm_model(f$project, f$cohort, nonlinear = "age"))
  expect_equal(canaries_in(mm_validate(m, f$cohort, B = 5)), 0L)
  expect_equal(canaries_in(mm_nomogram(m, out_dir = NULL)), 0L)
})

test_that("the model stores no copy of the cohort", {
  f <- fixture()
  m <- suppressWarnings(mm_model(f$project, f$cohort, nonlinear = "age"))
  stored <- vapply(m, function(el) {
    is.data.frame(el) && nrow(el) > 1L
  }, logical(1))
  expect_false(any(stored))

  # Reachable by any route, not merely absent from the top level. The
  # top-level check above passed for the whole time the cohort was sitting in
  # the environment of the fit's terms.
  reachable <- function(x, depth = 0L) {
    if (depth > 4L) return(FALSE)
    if (is.data.frame(x)) return(nrow(x) >= nrow(f$cohort))
    if (is.environment(x)) {
      return(any(vapply(ls(x), function(nm)
        reachable(get(nm, envir = x), depth + 1L), logical(1))))
    }
    if (is.list(x)) {
      return(any(vapply(x, reachable, logical(1), depth = depth + 1L)))
    }
    if (inherits(x, c("formula", "terms"))) {
      return(reachable(environment(x), depth + 1L))
    }
    FALSE
  }
  expect_false(reachable(m$formula))
  expect_false(reachable(m$fit$terms))
})

test_that("mm_predict reproduces rms::predict exactly", {
  f <- fixture()
  m <- suppressWarnings(mm_model(f$project, f$cohort, nonlinear = "age",
                interactions = list(c("prior_uti", "sex"))))
  mine <- mm_predict(m, f$cohort)$.pred
  old <- options(datadist = m$datadist)
  on.exit(options(old), add = TRUE)
  theirs <- as.numeric(stats::predict(m$fit, newdata = f$cohort,
                                      type = "fitted"))
  expect_equal(mine, theirs, tolerance = 1e-12)
})

test_that("a level the model never saw is refused by name", {
  f <- fixture()
  m <- suppressWarnings(mm_model(f$project, f$cohort))
  odd <- f$cohort[1:3, ]
  odd$sex <- "unrecorded"
  expect_error(mm_predict(m, odd), "unrecorded")
})

test_that("a missing predictor is refused, or returned as NA on request", {
  f <- fixture()
  m <- suppressWarnings(mm_model(f$project, f$cohort))
  gap <- f$cohort[1:4, ]
  gap$bmi[2] <- NA
  expect_error(mm_predict(m, gap), "missing predictor")
  out <- mm_predict(m, gap, on_missing = "na")
  expect_true(is.na(out$.pred[2]))
  expect_false(any(is.na(out$.pred[-2])))
})

test_that("extrapolation is labelled rather than hidden", {
  f <- fixture()
  m <- suppressWarnings(mm_model(f$project, f$cohort))
  far <- f$cohort[1:2, ]
  far$age <- c(5, 200)
  expect_true(all(mm_predict(m, far)$.extrapolated))
})

test_that("a split row with a missing split variable is not dropped", {
  f <- fixture()
  broken <- f$cohort
  broken$year[1] <- NA
  expect_error(mm_model(f$project, broken), "neither side of the split")
})
