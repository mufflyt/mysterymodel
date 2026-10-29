test_that("the denominator each percentage is taken over is shown", {
  cohort <- cp_synthetic_cohort(n = 400, seed = 1)
  e <- cp_eda(cohort, by = "event", vars = c("age", "sex"))
  expect_equal(e$table$variable[1], "(denominator)")
  expect_true("Overall" %in% names(e$table))
})

test_that("categorical percentages use the non-missing denominator and the missing count is reported beside them", {
  cohort <- data.frame(
    sex = factor(c("female", "female", "male", NA)),
    event = c(0, 1, 0, 1))
  e <- cp_eda(cohort, vars = "sex")
  female <- e$table[e$table$statistic == "female, n (%)", "Overall"]
  missing <- e$table[e$table$statistic == "missing, n (%)", "Overall"]
  # Two of the three recorded values are female, not two of four rows.
  expect_match(female, "66.7%")
  expect_match(missing, "25.0%")
})

test_that("continuous variables get both a mean and a median summary", {
  cohort <- cp_synthetic_cohort(n = 200, seed = 2)
  e <- cp_eda(cohort, vars = "age")
  expect_true("mean (SD)" %in% e$table$statistic)
  expect_true("median (p25, p75)" %in% e$table$statistic)
})

test_that("counts carry thousands separators", {
  cohort <- cp_synthetic_cohort(n = 2500, seed = 3)
  e <- cp_eda(cohort, vars = "age")
  expect_match(e$table[1, "Overall"], "2,500")
})

test_that("stratifying adds one column per level, plus overall", {
  cohort <- cp_synthetic_cohort(n = 200, seed = 4)
  e <- cp_eda(cohort, by = "event", vars = "age")
  expect_true(all(c("Overall", "event = 0", "event = 1") %in%
                    names(e$table)))
})

test_that("missingness is ranked worst first", {
  cohort <- cp_synthetic_cohort(n = 200, seed = 5)
  cohort$bmi[1:40] <- NA
  cohort$age[1:5] <- NA
  e <- cp_eda(cohort, vars = c("age", "bmi", "sex"))
  expect_equal(e$missing$variable[1], "bmi")
  expect_equal(e$missing$pct_missing[1], 20)
})

test_that("duplicated rows are counted rather than removed", {
  cohort <- cp_synthetic_cohort(n = 50, seed = 6)
  doubled <- rbind(cohort, cohort[1:3, ])
  e <- cp_eda(doubled, vars = "age")
  expect_equal(e$duplicates, 3L)
  expect_equal(e$n, 53L)
})

test_that("a cleaned cohort can be described directly", {
  raw <- cp_synthetic_cohort(n = 100, seed = 7)
  clean <- cp_clean(raw, rules = list("aged 40 or over" = ~ age >= 40))
  e <- cp_eda(clean, vars = "age")
  expect_equal(e$n, clean$n_out)
})

test_that("an absent column is named", {
  cohort <- cp_synthetic_cohort(n = 20, seed = 8)
  expect_error(cp_eda(cohort, vars = "weight"), "weight")
  expect_error(cp_eda(cohort, by = "centre"), "one column")
})
