# Recalibration: the corrections, and the two things a correction must never
# be mistaken for.
#
# The property worth pinning above all others is that a correction cannot
# reorder patients, so it cannot repair discrimination. Everything else here
# is arithmetic that can be checked against a known answer.

mm_recal_fixture <- function(n = 3000L, seed = 21L) {
  set.seed(seed)
  lp <- stats::rnorm(n, -1, 1.2)
  list(lp = lp, y = stats::rbinom(n, 1L, stats::plogis(lp)), n = n)
}

test_that("recalibrating a fit on its own rows returns no correction", {
  # THE ANCHOR. A maximum-likelihood logistic fit is calibrated on the sample
  # that produced it by construction, so the apparent intercept correction is
  # exactly 0 and the apparent slope exactly 1. Any drift here is an error in
  # the correction's arithmetic rather than a finding about the model, which is
  # what makes this the one case with a known answer.
  cohort <- mm_synthetic_cohort(n = 500, seed = 4)
  fit <- suppressWarnings(mm_model(
    mm_project("r", "event", c("age", "bmi"), positive_class = 1,
               cohort = cohort), cohort))
  lp <- as.numeric(fit$fit$linear.predictors)

  a <- mm_recal_intercept(lp, cohort$event, positive = 1)
  expect_lt(abs(a$a), 1e-6)
  expect_identical(a$n, 500L)
  expect_identical(a$events, sum(cohort$event))

  s <- mm_recal_slope(lp, cohort$event, positive = 1)
  expect_lt(abs(s$b - 1), 1e-6)
  expect_lt(abs(s$a), 1e-6)
  # b indistinguishable from 1 is the whole point, and the test is against 1
  # rather than against 0.
  expect_gt(s$b_p, 0.9)
  expect_lt(abs(s$b_z), 1e-4)
})

test_that("a known shift is recovered with the opposite sign", {
  # The outcome is generated from lp, and the recalibrator is handed lp + 0.8,
  # so the constant it finds must be about -0.8: the model as presented
  # predicts too high by that much on the log-odds scale.
  f <- mm_recal_fixture()
  r <- mm_recal_intercept(f$lp + 0.8, f$y, positive = 1)
  expect_lt(abs(r$a - (-0.8)), 0.15)
  # And the uncorrected sample needs no constant.
  expect_lt(abs(mm_recal_intercept(f$lp, f$y, positive = 1)$a), 0.15)
})

test_that("a correction cannot reorder any two patients", {
  # So it cannot change the c-statistic, and cannot be offered as a remedy for
  # a model that does not discriminate. This is asserted rather than assumed
  # because it is the claim the whole module rests on.
  f <- mm_recal_fixture(n = 500L)
  for (b in c(0.5, 1, 1.7)) {
    corrected <- mm_recal_apply(f$lp, a = 0.6, b = b)
    expect_identical(order(corrected), order(f$lp))
    expect_identical(rank(corrected, ties.method = "first"),
                     rank(f$lp, ties.method = "first"))
    expect_true(all(corrected > 0 & corrected < 1))
  }
  # Moving the level is what it DOES do: a positive constant raises every
  # probability.
  expect_true(all(mm_recal_apply(f$lp, 0.6) > stats::plogis(f$lp)))
})

test_that("a slope that would reorder or flatten is refused", {
  expect_error(mm_recal_apply(c(-1, 0, 1), a = 0, b = 0), "not a recalibration")
  expect_error(mm_recal_apply(c(-1, 0, 1), a = 0, b = -1), "reverse or flatten")
  expect_error(mm_recal_apply(c(-1, 0, 1), a = NA), "one finite number")
  expect_error(mm_recal_apply(c(-1, 0, 1), a = c(1, 2)), "one finite number")
  expect_error(mm_recal_apply(c(-1, 0, 1), a = Inf), "one finite number")
})

test_that("a sample with no outcome variation returns a reason, not a number", {
  f <- mm_recal_fixture(n = 100L)
  r <- mm_recal_intercept(f$lp, rep(0L, 100), positive = 0)
  expect_true(is.na(r$a))
  expect_match(r$reason, "no outcome variation")
  expect_identical(r$n, 100L)
  s <- mm_recal_slope(f$lp, rep(1L, 100), positive = 1)
  expect_true(is.na(s$b))
  expect_match(s$reason, "no outcome variation")
})

test_that("missing rows are dropped and the count says so", {
  f <- mm_recal_fixture(n = 400L)
  lp <- f$lp
  lp[1:7] <- NA
  y <- f$y
  y[400] <- NA
  r <- mm_recal_intercept(lp, y, positive = 1)
  expect_identical(r$n, 400L - 8L)
  expect_error(mm_recal_intercept(rep(NA_real_, 10), rep(1:0, 5), positive = 1),
               "no row has both")
  expect_error(mm_recal_intercept(f$lp[1:10], f$y, positive = 1),
               "10 linear predictor\\(s\\) for 400 outcome\\(s\\)")
})

test_that("a cluster changes the standard error and says that it did", {
  skip_if_not_installed("sandwich")
  f <- mm_recal_fixture(n = 600L)
  # Each cluster contributes three rows, so the model-based standard error
  # treats correlated rows as independent and is too small.
  cl <- rep(seq_len(200), each = 3)
  plain <- mm_recal_intercept(f$lp, f$y, positive = 1)
  clustered <- mm_recal_intercept(f$lp, f$y, cluster = cl, positive = 1)
  expect_false(plain$cluster_robust)
  expect_true(clustered$cluster_robust)
  expect_identical(clustered$n_clusters, 200L)
  expect_true(is.na(plain$n_clusters))
  expect_equal(clustered$a, plain$a)
  expect_false(isTRUE(all.equal(clustered$se, plain$se)))
  expect_match(clustered$reason, "cluster-robust over 200 cluster")
  expect_match(plain$reason, "rows treated as independent")
  # A cluster identifier with one row per cluster is not clustering, and must
  # not be reported as though it were.
  solo <- mm_recal_intercept(f$lp, f$y, cluster = seq_along(f$lp), positive = 1)
  expect_false(solo$cluster_robust)
})

test_that("Rubin's rules carry the between-imputation variance", {
  # Checked against arithmetic done by hand. Identical estimates have no
  # between-imputation variance, so the pooled standard error is the common
  # within-imputation one and nothing is inflated.
  r <- mm_rubin(c(1, 1, 1), c(0.1, 0.1, 0.1))
  expect_equal(r$est, 1)
  expect_equal(r$se, 0.1)
  expect_equal(r$between, 0)
  expect_equal(r$fmi, 0)
  expect_identical(r$m, 3L)

  # Spread estimates must inflate it: within 0.01, between var(c(0.9,1,1.1)) =
  # 0.01, total = 0.01 + (1 + 1/3) * 0.01.
  s <- mm_rubin(c(0.9, 1, 1.1), c(0.1, 0.1, 0.1))
  expect_equal(s$between, stats::var(c(0.9, 1, 1.1)))
  expect_equal(s$se, sqrt(0.01 + (1 + 1 / 3) * stats::var(c(0.9, 1, 1.1))))
  expect_gt(s$se, r$se)
  expect_gt(s$fmi, 0)

  # One imputation has no between-imputation variance to measure, which is a
  # different thing from an unknown one.
  one <- mm_rubin(1.5, 0.2)
  expect_equal(one$between, 0)
  expect_identical(one$m, 1L)
  expect_equal(one$se, 0.2)
  expect_identical(one$df, Inf)
})

test_that("an imputation that failed is dropped and counted, not averaged in", {
  r <- mm_rubin(c(1, NA, 1.2, Inf), c(0.1, 0.1, 0.1, 0.1))
  expect_identical(r$m, 2L)
  expect_identical(r$m_dropped, 2L)
  expect_match(r$reason, "2 dropped as non-finite")
  none <- mm_rubin(c(NA, NA), c(NA, NA))
  expect_true(is.na(none$est))
  expect_identical(none$m, 0L)
  expect_match(none$reason, "no imputation produced a finite estimate")
  expect_error(mm_rubin(c(1, 2), 0.1), "2 estimate\\(s\\) and 1 standard error")
})

test_that("pooling identical imputations equals the single-sample answer", {
  f <- mm_recal_fixture(n = 500L)
  single <- mm_recal_intercept(f$lp, f$y, positive = 1)
  pooled <- mm_recal_mi(cbind(f$lp, f$lp, f$lp), f$y, positive = 1)
  expect_equal(pooled$a, single$a)
  expect_equal(pooled$se_a, single$se)
  expect_identical(pooled$m, 3L)
  # The intercept-only form leaves the slope alone, and says so with 1.
  expect_identical(pooled$b, 1)
  expect_true(is.na(pooled$b_p))

  two <- mm_recal_mi(cbind(f$lp, f$lp), f$y, form = "two-parameter",
                     positive = 1)
  expect_lt(abs(two$b - mm_recal_slope(f$lp, f$y, positive = 1)$b), 1e-8)
  expect_true(is.finite(two$b_p))
  expect_match(two$reason, "two-parameter")

  expect_error(mm_recal_mi(cbind(f$lp, f$lp), f$y[1:10], positive = 1),
               "row\\(s\\) of linear predictors for 10 outcome")
  expect_error(mm_recal_mi(matrix(numeric(0), nrow = 500), f$y, positive = 1),
               "no columns")
})

test_that("a stratum too small to estimate returns a reason, not noise", {
  f <- mm_recal_fixture(n = 400L)
  stratum <- c(rep("big", 380), rep("small", 20))
  out <- mm_recal_by(f$lp, f$y, stratum, min_n = 50, positive = 1)
  expect_identical(nrow(out), 2L)
  expect_identical(out$stratum, c("big", "small"))
  expect_false(is.na(out$a[out$stratum == "big"]))
  expect_true(is.na(out$a[out$stratum == "small"]))
  expect_match(out$reason[out$stratum == "small"], "below the 50-row floor")
  expect_identical(sum(out$n), 400L)
  # A stratum large enough but with no events is a different refusal. The
  # outcome is zeroed for exactly the rows this stratum names, which an
  # earlier version of this block got wrong by reusing the stratum above.
  two_groups <- c(rep("big", 300), rep("none", 100))
  y <- f$y
  y[two_groups == "none"] <- 0L
  flat <- mm_recal_by(f$lp, y, two_groups, min_n = 50, positive = 1)
  expect_true(is.na(flat$a[flat$stratum == "none"]))
  expect_match(flat$reason[flat$stratum == "none"], "no outcome variation")
  expect_error(mm_recal_by(f$lp, f$y, stratum[1:10], positive = 1),
               "10 stratum value\\(s\\)")
  expect_error(mm_recal_by(f$lp, f$y, rep(NA_character_, 400), positive = 1),
               "every stratum value is missing")
})

test_that("every entry point refuses an event level the outcome lacks", {
  f <- mm_recal_fixture(n = 200L)
  yf <- factor(ifelse(f$y == 1L, "Yes", "No"), levels = c("No", "Yes"))
  expect_error(mm_recal_intercept(f$lp, yf, positive = "Maybe"),
               "mm_recal_intercept\\(\\): `positive` is \"Maybe\"")
  expect_error(mm_recal_slope(f$lp, yf, positive = "Maybe"),
               "mm_recal_slope\\(\\): `positive` is \"Maybe\"")
  expect_error(mm_recal_by(f$lp, yf, rep("a", 200), positive = "Maybe"),
               "mm_recal_by\\(\\): `positive` is \"Maybe\"")
  expect_error(mm_recal_mi(cbind(f$lp), yf, positive = "Maybe"),
               "mm_recal_mi\\(\\): `positive` is \"Maybe\"")
  # Each names itself, so a message cannot send a reader to the wrong function.
  expect_error(mm_recal_slope(f$lp, yf, positive = "Maybe"), "mm_recal_slope")
})

test_that("a factor outcome recalibrates the same as its 0/1 coding", {
  # The port's reason for routing through mm_event_indicator(): a correction
  # read the other way round from the fit would be silently wrong, and the
  # original's as.numeric() would have made a No/Yes factor into 1 and 2.
  f <- mm_recal_fixture(n = 400L)
  yf <- factor(ifelse(f$y == 1L, "Yes", "No"), levels = c("No", "Yes"))
  expect_equal(mm_recal_intercept(f$lp, yf, positive = "Yes")$a,
               mm_recal_intercept(f$lp, f$y, positive = 1)$a)
  expect_equal(mm_recal_slope(f$lp, yf, positive = "Yes")$b,
               mm_recal_slope(f$lp, f$y, positive = 1)$b)
})
