# What a reported number means, and what it must not claim. Three things an
# audit of PR #10 found: an estimate dying with its interval, a column of skill
# scores against different references, and a corrected intercept thrown away.

report_cohort <- function(n = 600, seed = 1978) {
  mm_synthetic_cohort(n = n, prevalence = 0.13, seed = seed)
}
report_project <- function(cohort) {
  mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
             positive_class = 1, cohort = cohort, split_var = "year",
             split_at = 2023, cluster_id = "pid", seed = 1978)
}

test_that("the c-statistic outlives its interval", {
  # ci.auc() returns all NA when DeLong cannot be computed, and the estimate
  # used to be read out of the middle of it, so a calculable c-statistic was
  # discarded with the interval it did not have.
  y <- c(rep(0L, 120), 1L)
  set.seed(1)
  p <- c(runif(120, 0.02, 0.3), 0.6)
  row <- suppressWarnings(mysterymodel:::mm_metrics(p, y, basis = "probe"))

  # Mann-Whitney U, computed here and owing nothing to pROC.
  r <- rank(p)
  by_hand <- (sum(r[y == 1]) - 1 * 2 / 2) / (1 * 120)

  expect_equal(row$c_stat, by_hand)
  expect_true(is.na(row$c_lower))
  expect_true(is.na(row$c_upper))
  expect_match(row$note, "no interval here")
})

test_that("a calibration term that did not converge is withheld by name", {
  y <- c(rep(0L, 120), 1L)
  set.seed(1)
  p <- c(runif(120, 0.02, 0.3), 0.6)
  row <- suppressWarnings(mysterymodel:::mm_metrics(p, y, basis = "probe"))

  # The slope's fit is the one that fails on these data. Naming which term was
  # withheld is the difference between a reader knowing and guessing.
  slope_fit <- suppressWarnings(
    stats::glm(y ~ stats::qlogis(p), family = stats::binomial()))
  expect_false(slope_fit$converged)
  expect_true(is.na(row$cal_slope))
  expect_match(row$note, "calibration slope is withheld")

  # The intercept's fit does converge on the same data, so it is reported.
  int_fit <- suppressWarnings(stats::glm(
    y ~ 1, family = stats::binomial(), offset = stats::qlogis(p)))
  expect_true(int_fit$converged)
  expect_equal(row$cal_intercept, unname(stats::coef(int_fit)[1]))
})

test_that("a well behaved sample carries no asides at all", {
  cohort <- report_cohort()
  model <- suppressWarnings(
    mm_model(report_project(cohort), cohort, nonlinear = "age"))
  v <- mm_validate(model, cohort, B = 20)
  held <- v$metrics[v$metrics$basis == "held out", ]

  expect_false(is.na(held$c_lower))
  expect_false(is.na(held$cal_slope))
  expect_no_match(held$note, "withheld")
  expect_no_match(held$note, "no interval here")
})

test_that("one reference scales the whole scaled-Brier column", {
  cohort <- report_cohort()
  project <- report_project(cohort)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- mm_validate(model, cohort, B = 30, full_process = TRUE)

  # Computed from the development rows here, not read back off the object.
  dev <- cohort[cohort$year < 2023, ]
  expected_ref <- mean(dev$event) * (1 - mean(dev$event))

  scored <- v$metrics[!is.na(v$metrics$brier), ]
  expect_gt(nrow(scored), 1L)
  expect_true(all(abs(scored$brier_ref - expected_ref) < 1e-12))
  expect_true(all(abs(scored$brier_scaled -
                        (1 - scored$brier / expected_ref)) < 1e-12))

  # The held-out rows have a prevalence of their own, so the column would
  # otherwise mix references. Its own value is kept in the note rather than
  # lost, and it really is a different number.
  held <- cohort[cohort$year >= 2023, ]
  own_ref <- mean(held$event) * (1 - mean(held$event))
  expect_false(isTRUE(all.equal(own_ref, expected_ref)))
  held_row <- v$metrics[v$metrics$basis == "held out", ]
  expect_match(held_row$note, "not this sample's own")
  expect_match(held_row$note,
               sprintf("%.4f", 1 - held_row$brier / own_ref), fixed = TRUE)
})

test_that("used on its own, mm_metrics still scales by the sample's own rate", {
  # The reference is an argument, not a new rule. A caller building a subgroup
  # table gets the conventional within-sample skill score unless they ask
  # otherwise.
  set.seed(4)
  y <- rbinom(300, 1, 0.2)
  p <- pmin(pmax(0.2 + 0.1 * scale(y)[, 1] + rnorm(300, 0, 0.05), 0.01), 0.99)
  row <- mysterymodel:::mm_metrics(p, y, basis = "probe")
  own <- mean(y) * (1 - mean(y))
  expect_equal(row$brier_ref, own)
  expect_equal(row$brier_scaled, 1 - mean((p - y)^2) / own)
  expect_no_match(row$note, "not this sample's own")
})

test_that("the corrected calibration intercept rms computes is reported", {
  cohort <- report_cohort()
  project <- report_project(cohort)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- mm_validate(model, cohort, B = 60)
  row <- v$metrics[v$metrics$basis == "bootstrap, fixed model", ]

  old <- options(datadist = model$datadist)
  on.exit(options(old), add = TRUE)
  dev <- cohort[cohort$year < 2023, ]
  set.seed(project$seed)
  direct <- rms::validate(model$fit, B = 60,
                          cluster = as.character(dev$pid))

  expect_true("Intercept" %in% rownames(direct))
  expect_false(is.na(row$cal_intercept))
  expect_equal(row$cal_intercept,
               unname(direct["Intercept", "index.corrected"]))
  expect_equal(row$cal_slope, unname(direct["Slope", "index.corrected"]))
})

# The resample-count contract. A caller who asks for 2.7 resamples asks for
# something that does not exist, and answering with 2 answers a different
# question. Checked before any seed is set, so a refusal leaves the
# random-number state alone.

test_that("every kind of impossible resample count is refused", {
  cohort <- report_cohort(n = 300)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  expect_error(mm_validate(model, cohort, B = 2.7), "not a whole number")
  expect_error(mm_validate(model, cohort, B = NA_real_), "not a number")
  expect_error(mm_validate(model, cohort, B = NaN), "NaN")
  expect_error(mm_validate(model, cohort, B = Inf), "infinite number")
  expect_error(mm_validate(model, cohort, B = -Inf), "infinite number")
  expect_error(mm_validate(model, cohort, B = 0), "At least one resample")
  expect_error(mm_validate(model, cohort, B = -5), "At least one resample")
  expect_error(mm_validate(model, cohort, B = c(10, 20)), "has length 2")
  expect_error(mm_validate(model, cohort, B = "200"), "class character")
  expect_error(mm_validate(model, cohort, B = numeric(0)), "has length 0")
  expect_error(mm_validate(model, cohort, B = TRUE), "class logical")

  # A count written with a decimal point is still a count.
  expect_equal(mm_validate(model, cohort, B = 20.0)$B, 20L)
})

test_that("a refused resample count does not advance the RNG", {
  # The check has to come before the seed is set, or a rejected call would
  # change the next accepted one.
  cohort <- report_cohort(n = 300)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  set.seed(99)
  state <- .Random.seed
  for (impossible in list(2.7, NA_real_, Inf, 0, c(1, 2), "x")) {
    expect_error(mm_validate(model, cohort, B = impossible))
  }
  expect_identical(state, .Random.seed)
})

test_that("the lower-level bootstrap applies the same contract", {
  # Validating the public entry point while an internal one still truncates
  # would be the same defect one call deeper.
  cohort <- report_cohort(n = 300)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  expect_error(mysterymodel:::mm_full_process(model, cohort, B = 2.7),
               "not a whole number")
  expect_error(mysterymodel:::mm_check_resamples(2.7), "not a whole number")
})

test_that("valid resample counts are statistically unchanged", {
  # The contract rejects; it must not alter an accepted call.
  cohort <- report_cohort(n = 300)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  twice <- replicate(2, mm_validate(model, cohort, B = 25)$metrics$c_stat,
                     simplify = FALSE)
  expect_identical(twice[[1]], twice[[2]])
  expect_identical(mm_validate(model, cohort, B = 25L)$metrics$c_stat,
                   mm_validate(model, cohort, B = 25.0)$metrics$c_stat)
})
