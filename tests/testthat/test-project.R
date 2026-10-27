# One test per fail-closed condition the specification names in sections 5
# and 10. Each is a condition that, left unchecked, produces a result that
# looks like a finding rather than like an error.

cohort_ok <- function() {
  data.frame(
    event = c(0, 1, 0, 1, 0, 1),
    age   = c(60, 71, 55, 68, 49, 77),
    bmi   = c(28, 31, 25, 33, 22, 36),
    year  = c(2021, 2021, 2022, 2023, 2023, 2024),
    pid   = c("a", "a", "b", "c", "d", "e"),
    stringsAsFactors = FALSE
  )
}

test_that("a valid configuration records what it was given", {
  p <- cp_project("uds", "event", c("age", "bmi"), seed = 7)
  expect_s3_class(p, "cp_project")
  expect_identical(p$slug, "uds")
  expect_identical(p$predictors, c("age", "bmi"))
  expect_identical(p$seed, 7L)
  expect_null(p$split_var)
})

test_that("the outcome cannot also be a predictor", {
  # Unchecked, this reports perfect discrimination, which reads as success.
  expect_error(cp_project("uds", "event", c("event", "age")),
               "perfect discrimination")
})

test_that("a repeated predictor is refused", {
  expect_error(cp_project("uds", "event", c("age", "age")), "repeats")
})

test_that("temporal validation without a time field is refused", {
  expect_error(cp_project("uds", "event", "age", split_var = "year"),
               "without a time field")
  expect_error(cp_project("uds", "event", "age", split_at = 2023),
               "without a time field")
})

test_that("a split is recorded whole", {
  p <- cp_project("uds", "event", "age", split_var = "year",
                  split_at = 2023)
  expect_identical(p$split_var, "year")
  expect_identical(p$split_at, 2023)
})

test_that("columns absent from the cohort are named", {
  expect_error(
    cp_project("uds", "event", c("age", "weight"), cohort = cohort_ok()),
    "weight")
  expect_silent(
    cp_project("uds", "event", c("age", "bmi"), cohort = cohort_ok()))
})

test_that("a cluster column must exist in the cohort", {
  expect_error(
    cp_project("uds", "event", "age", cohort = cohort_ok(),
               cluster_id = "patient"),
    "patient")
  p <- cp_project("uds", "event", "age", cohort = cohort_ok(),
                  cluster_id = "pid")
  expect_identical(p$cluster_id, "pid")
})

test_that("an outcome that does not vary is refused", {
  flat <- cohort_ok()
  flat$event <- 0
  expect_error(cp_project("uds", "event", "age", cohort = flat),
               "does not vary")
})

test_that("an unobserved positive class is refused", {
  # An inverted positive class inverts every risk the model reports, and
  # nothing downstream looks wrong.
  expect_error(
    cp_project("uds", "event", "age", positive_class = "Yes",
               cohort = cohort_ok()),
    "not an observed value")
  p <- cp_project("uds", "event", "age", positive_class = "1",
                  cohort = cohort_ok())
  expect_identical(p$positive_class, "1")
})

test_that("a non-whole seed is refused", {
  expect_error(cp_project("uds", "event", "age", seed = 1.5),
               "whole number")
})

test_that("printing names the split and the event rather than hiding them", {
  p <- cp_project("uds", "event", "age", positive_class = "1",
                  cohort = cohort_ok(), split_var = "year",
                  split_at = 2023, cluster_id = "pid")
  expect_output(print(p), "event = 1")
  expect_output(print(p), "year < 2023")
  expect_output(print(p), "cluster    pid")
  expect_output(print(cp_project("uds", "event", "age")), "split      none")
})
