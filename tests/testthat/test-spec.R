test_that("a valid spec records what it was given", {
  s <- mm_spec("matched", c("step_1_score", "sex"), seed = 7)
  expect_s3_class(s, "mysterymodel_spec")
  expect_identical(s$outcome, "matched")
  expect_identical(s$predictors, c("step_1_score", "sex"))
  expect_identical(s$seed, 7L)
  expect_null(s$split_var)
})

test_that("the outcome cannot also be a predictor", {
  # The failure this catches reports perfect discrimination, which looks like
  # success rather than like a bug.
  expect_error(mm_spec("matched", c("matched", "sex")), "perfect discrimination")
})

test_that("a repeated predictor is refused", {
  expect_error(mm_spec("matched", c("sex", "sex")), "repeats")
})

test_that("half a split is refused", {
  expect_error(mm_spec("matched", "sex", split_var = "app_year"), "go together")
  expect_error(mm_spec("matched", "sex", split_at = 2023), "go together")
})

test_that("a split is recorded whole", {
  s <- mm_spec("matched", "sex", split_var = "app_year", split_at = 2023)
  expect_identical(s$split_var, "app_year")
  expect_identical(s$split_at, 2023)
})

test_that("columns absent from data are named", {
  d <- data.frame(matched = 1, sex = "f")
  expect_error(mm_spec("matched", c("sex", "step_1_score"), data = d),
               "step_1_score")
  expect_silent(mm_spec("matched", "sex", data = d))
})

test_that("a non-whole seed is refused", {
  expect_error(mm_spec("matched", "sex", seed = 1.5), "whole number")
})

test_that("printing names the split rather than hiding it", {
  s <- mm_spec("matched", "sex", split_var = "app_year", split_at = 2023)
  expect_output(print(s), "app_year < 2023")
  expect_output(print(mm_spec("matched", "sex")), "split      none")
})
