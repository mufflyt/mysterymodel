# The v0.1 acceptance gate is "no silent row deletion". Every test here is a
# way that could happen.

test_that("the ledger reconciles rows in against rows out", {
  raw <- cp_synthetic_cohort(n = 300, seed = 1)
  clean <- cp_clean(raw, rules = list(
    "aged 40 or over" = ~ age >= 40,
    "plausible BMI"   = ~ bmi >= 16 & bmi <= 55))
  expect_equal(clean$n_in - clean$n_excluded, clean$n_out)
  expect_equal(nrow(clean$data), clean$n_out)
})

test_that("an undetermined criterion is its own exclusion, not a pass", {
  # Treating unknown eligibility as eligible and as ineligible are different
  # studies, so the rows get their own line in the diagram.
  raw <- cp_synthetic_cohort(n = 200, seed = 2)
  raw$bmi[c(5, 11, 50)] <- NA
  clean <- cp_clean(raw, rules = list("plausible BMI" = ~ bmi <= 55))
  undecided <- clean$ledger[grepl("could not be determined",
                                  clean$ledger$reason), ]
  expect_equal(nrow(undecided), 1L)
  expect_equal(undecided$n_excluded, 3L)
  expect_false(any(is.na(clean$data$bmi)))
})

test_that("no rules passes every row through, with a ledger", {
  raw <- cp_synthetic_cohort(n = 50, seed = 3)
  clean <- cp_clean(raw)
  expect_equal(clean$n_out, 50L)
  expect_equal(clean$n_excluded, 0L)
  expect_equal(nrow(clean$ledger), 1L)
})

test_that("exclusions are attributed to the rule that caused them", {
  raw <- data.frame(age = c(30, 50, 70), bmi = c(10, 30, 30))
  clean <- cp_clean(raw, rules = list(
    "aged 40 or over" = ~ age >= 40,
    "plausible BMI"   = ~ bmi >= 16))
  age_row <- clean$ledger[clean$ledger$rule == "aged 40 or over", ]
  bmi_row <- clean$ledger[clean$ledger$rule == "plausible BMI", ]
  expect_equal(age_row$n_excluded, 1L)
  # The implausible BMI row was already gone on age, so it is not counted
  # twice. Sequential attribution is what makes the ledger add up.
  expect_equal(nrow(bmi_row), 0L)
  expect_equal(clean$n_out, 2L)
})

test_that("an unnamed rule is refused", {
  raw <- cp_synthetic_cohort(n = 20, seed = 4)
  expect_error(cp_clean(raw, rules = list(~ age >= 40)), "needs a name")
})

test_that("a bare expression is refused, with the formula form shown", {
  raw <- cp_synthetic_cohort(n = 20, seed = 4)
  expect_error(cp_clean(raw, rules = list("old" = TRUE)), "not formulas")
})

test_that("a two-sided formula is refused", {
  raw <- cp_synthetic_cohort(n = 20, seed = 4)
  expect_error(cp_clean(raw, rules = list("odd" = age ~ bmi)),
               "one-sided")
})

test_that("a rule of the wrong length is refused", {
  raw <- cp_synthetic_cohort(n = 20, seed = 4)
  expect_error(cp_clean(raw, rules = list("short" = ~ c(TRUE, FALSE))),
               "one TRUE or FALSE per row")
})

test_that("a non-logical rule is refused", {
  raw <- cp_synthetic_cohort(n = 20, seed = 4)
  expect_error(cp_clean(raw, rules = list("numeric" = ~ age)),
               "one TRUE or FALSE per row")
})

test_that("a rule naming an absent column says which rule failed", {
  raw <- cp_synthetic_cohort(n = 20, seed = 4)
  expect_error(cp_clean(raw, rules = list("weighty" = ~ weight > 2)),
               "weighty")
})

test_that("a rule can see variables from the calling frame", {
  raw <- cp_synthetic_cohort(n = 100, seed = 6)
  floor_age <- 50
  clean <- cp_clean(raw, rules = list("over the floor" = ~ age >= floor_age))
  expect_equal(clean$n_out, sum(raw$age >= 50))
})
