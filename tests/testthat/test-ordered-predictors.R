# What an ordered predictor is allowed to change, and what it must not.
#
# These run on a synthetic cohort rather than on a downloaded one. Every
# property here is an invariance or a degree-of-freedom count, so it needs a
# four-level ordered factor and not anyone's particular data; the external
# benchmark against published coefficients lives in data-raw/ because that is
# the only part that needs the data itself.

ord_cohort <- function(n = 700, seed = 1978) {
  set.seed(seed)
  rank_values <- sample(1:4, n, TRUE, prob = c(0.15, 0.35, 0.3, 0.2))
  frame <- data.frame(
    gre = round(rnorm(n, 587, 115)),
    gpa = round(pmin(pmax(rnorm(n, 3.39, 0.38), 2), 4), 2),
    rank_nominal = factor(rank_values, levels = 1:4),
    rank_ordered = ordered(rank_values, levels = 1:4),
    rank_score = as.numeric(rank_values))
  lp <- -3.99 + 0.00226 * frame$gre + 0.804 * frame$gpa -
    c(0, 0.675, 1.340, 1.551)[rank_values]
  frame$admit <- rbinom(n, 1L, stats::plogis(lp))
  frame
}
ord_fit <- function(cohort, predictor, ...) {
  project <- mm_project("ord", "admit", c("gre", "gpa", predictor),
                        positive_class = 1, cohort = cohort, seed = 1978,
                        ...)
  suppressWarnings(mm_model(project, cohort))
}

test_that("an ordered factor with numeric levels is fitted, not refused", {
  # rms accepts one whose level labels parse as numbers and spends a linear
  # term in the scores plus a departure per level above the second. An
  # earlier version of the guard here asked `is.numeric(levels(x))`, which is
  # always FALSE because levels() always returns character, and so refused
  # every ordered factor including the ones rms fits.
  cohort <- ord_cohort()
  fitted <- ord_fit(cohort, "rank_ordered")
  expect_s3_class(fitted, "mm_model")
  expect_true(any(grepl("rank_ordered", names(stats::coef(fitted$fit)))))
  expect_false(mysterymodel:::mm_unfittable_ordered(cohort$rank_ordered))
  expect_true(mysterymodel:::mm_unfittable_ordered(
    ordered(c("low", "high"), levels = c("low", "high"))))
})

test_that("ordered and nominal are the same model, differently written", {
  # The property that matters: a four-level factor spends three degrees of
  # freedom either way, so the two parameterisations span one space and must
  # agree on every fitted probability and on the likelihood. Only the
  # coefficients may differ.
  cohort <- ord_cohort()
  nominal <- ord_fit(cohort, "rank_nominal")
  ordered_fit <- ord_fit(cohort, "rank_ordered")

  expect_equal(mm_predict(nominal, cohort)$.pred,
               mm_predict(ordered_fit, cohort)$.pred, tolerance = 1e-10)
  expect_equal(unname(nominal$fit$deviance[2]),
               unname(ordered_fit$fit$deviance[2]), tolerance = 1e-10)
  expect_equal(unname(nominal$fit$stats[["Model L.R."]]),
               unname(ordered_fit$fit$stats[["Model L.R."]]),
               tolerance = 1e-10)
  expect_equal(length(stats::coef(nominal$fit)),
               length(stats::coef(ordered_fit$fit)))
  expect_equal(unname(nominal$fit$stats[["d.f."]]),
               unname(ordered_fit$fit$stats[["d.f."]]))

  # Different names and different numbers, which is the whole point of
  # comparing probabilities rather than coefficients.
  expect_false(identical(names(stats::coef(nominal$fit)),
                         names(stats::coef(ordered_fit$fit))))
  expect_false(isTRUE(all.equal(unname(stats::coef(nominal$fit)),
                                unname(stats::coef(ordered_fit$fit)))))
})

test_that("a numeric score is a smaller model and is not reached by accident", {
  cohort <- ord_cohort()
  nominal <- ord_fit(cohort, "rank_nominal")
  scored <- ord_fit(cohort, "rank_score")

  # Three degrees of freedom for the factor against one for the score.
  expect_equal(unname(nominal$fit$stats[["d.f."]]) -
                 unname(scored$fit$stats[["d.f."]]), 2)
  expect_equal(length(stats::coef(nominal$fit)) -
                 length(stats::coef(scored$fit)), 2L)
  # A restricted model cannot fit better.
  expect_gte(unname(scored$fit$deviance[2]), unname(nominal$fit$deviance[2]))
  expect_false(isTRUE(all.equal(mm_predict(nominal, cohort)$.pred,
                                mm_predict(scored, cohort)$.pred)))

  # And an ordered factor is never silently turned into its scores: the
  # schema records it as categorical with its levels.
  ordered_fit <- ord_fit(cohort, "rank_ordered")
  expect_identical(ordered_fit$schema$predictors$rank_ordered$type,
                   "categorical")
  expect_identical(ordered_fit$schema$predictors$rank_ordered$levels,
                   c("1", "2", "3", "4"))
  expect_identical(scored$schema$predictors$rank_score$type, "numeric")
})

test_that("releveling moves the baseline and nothing else", {
  cohort <- ord_cohort()
  first <- ord_fit(cohort, "rank_nominal")
  last <- ord_fit(cohort, "rank_nominal",
                  reference = list(rank_nominal = "4"))

  expect_equal(mm_predict(first, cohort)$.pred,
               mm_predict(last, cohort)$.pred, tolerance = 1e-10)
  expect_equal(unname(first$fit$deviance[2]),
               unname(last$fit$deviance[2]), tolerance = 1e-10)
  expect_true("rank_nominal=4" %in% names(stats::coef(first$fit)))
  expect_true("rank_nominal=1" %in% names(stats::coef(last$fit)))

  # The contrast reverses, which is the arithmetic that proves the relevel
  # did what it says: 4 against 1 is the negative of 1 against 4.
  expect_equal(stats::coef(first$fit)[["rank_nominal=4"]],
               -stats::coef(last$fit)[["rank_nominal=1"]],
               tolerance = 1e-8)
})

test_that("mysterymodel agrees with glm, an implementation it does not use", {
  # rms is the engine this package fits with, so agreeing with it is nearly
  # a tautology. glm() ships with R and shares no code with rms, which makes
  # it the independent check.
  cohort <- ord_cohort()
  for (predictor in c("rank_nominal", "rank_ordered", "rank_score")) {
    ours <- ord_fit(cohort, predictor)
    reference <- stats::glm(
      stats::as.formula(paste("admit ~ gre + gpa +", predictor)),
      data = cohort, family = stats::binomial())
    expect_equal(mm_predict(ours, cohort)$.pred,
                 unname(stats::predict(reference, type = "response")),
                 tolerance = 1e-6, info = predictor)
    expect_equal(unname(ours$fit$deviance[2]),
                 unname(stats::deviance(reference)),
                 tolerance = 1e-6, info = predictor)
  }
})

test_that("an ordered factor whose labels are not numbers is refused", {
  cohort <- ord_cohort()
  cohort$band <- ordered(c("low", "mid", "high")[
    pmin(3L, as.integer(cohort$rank_nominal))],
    levels = c("low", "mid", "high"))
  expect_error(mm_project("ord", "admit", c("gre", "band"),
                          positive_class = 1, cohort = cohort),
               "levels are not numbers")
  expect_error(mm_project("ord", "admit", c("gre", "band"),
                          positive_class = 1, cohort = cohort),
               "judgement about spacing")
})
