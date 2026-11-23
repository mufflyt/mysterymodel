# Net benefit, checked against dcurves and against the three ways the version
# this was ported from got its INPUTS wrong while its formula was right.
#
# D01-D02 are the agreement. D03-D08 are negative controls: each was a real
# defect in the original inline implementation, every one latent because that
# function was defined and never called. The port must refuse or handle each,
# and the old behaviour must not come back.

mm_dc_fixture <- function(n = 1000L, seed = 7L) {
  set.seed(seed)
  lp <- stats::rnorm(n, 0, 1.3)
  list(lp = lp, y = stats::rbinom(n, 1L, stats::plogis(lp)),
       p = stats::plogis(lp), th = seq(0, 0.5, by = 0.05))
}

dcurves_reference <- function(variable, pred, obs, thresholds) {
  d <- dcurves::dca(obs ~ pred,
                    data = data.frame(obs = obs, pred = pred),
                    thresholds = thresholds)$dca
  d$net_benefit[d$variable == variable]
}

test_that("D01 the model curve agrees with dcurves::dca", {
  skip_if_not_installed("dcurves")
  f <- mm_dc_fixture()
  ours <- mm_decision_curve(f$y, f$p, f$th, positive = 1)$net_benefit_model
  ref <- suppressMessages(dcurves_reference("pred", f$p, f$y, f$th))
  expect_lt(max(abs(ours - ref)), 1e-12)
})

test_that("D02 the treat-all curve agrees, and both equal prevalence at zero", {
  skip_if_not_installed("dcurves")
  f <- mm_dc_fixture()
  o <- mm_decision_curve(f$y, f$p, f$th, positive = 1)
  ref <- suppressMessages(dcurves_reference("all", f$p, f$y, f$th))
  expect_lt(max(abs(o$net_benefit_all - ref)), 1e-12)
  # At a threshold of zero every patient is treated, so both strategies are
  # the prevalence. This one needs no reference implementation to check.
  expect_lt(abs(o$net_benefit_model[1] - mean(f$y)), 1e-12)
  expect_lt(abs(o$net_benefit_all[1] - mean(f$y)), 1e-12)
})

test_that("the arithmetic is right on a fixture small enough to do by hand", {
  # Four patients, threshold 0.5, so the weight on a false positive is
  # 0.5 / 0.5 = 1. Treated are those at or above 0.5: one event, one non-event.
  # Model: 1/4 - (1/4 * 1) = 0. Treat all: 2/4 - (2/4 * 1) = 0.
  o <- mm_decision_curve(c(1, 1, 0, 0), c(0.9, 0.4, 0.6, 0.1), 0.5,
                         positive = 1)
  expect_equal(o$net_benefit_model, 0)
  expect_equal(o$net_benefit_all, 0)
  expect_equal(o$net_benefit_none, 0)
  expect_equal(o$prevalence, 0.5)
  expect_equal(o$n, 4L)
})

test_that("D03 a factor outcome is handled, not silently flatlined at zero", {
  # THE DEFECT THAT WOULD HAVE REACHED A READER. `obs == 1` on a No/Yes factor
  # is FALSE everywhere, so true and false positives were both zero and the
  # curve returned 0 at every threshold, which reads as "no clinical utility"
  # rather than as an error.
  f <- mm_dc_fixture()
  yf <- factor(ifelse(f$y == 1L, "Yes", "No"), levels = c("No", "Yes"))
  from_factor <- mm_decision_curve(yf, f$p, f$th, positive = "Yes")
  from_01 <- mm_decision_curve(f$y, f$p, f$th, positive = 1)
  expect_identical(from_factor$net_benefit_model, from_01$net_benefit_model)
  expect_identical(from_factor$net_benefit_all, from_01$net_benefit_all)
  # And emphatically not zero.
  expect_lt(abs(from_factor$net_benefit_model[1] - mean(f$y)), 1e-12)
  expect_true(any(from_factor$net_benefit_model > 0.1))
})

test_that("an event level the outcome does not carry is refused by name", {
  # The port routes outcome coercion through mm_event_indicator(), the rule
  # the rest of the package uses, which takes a declared level on trust
  # because mm_project() has already checked it. Here there is no project, so
  # an unrecognised level would return all zeros and the caller would be told
  # their outcome has one class. True, and not the problem.
  f <- mm_dc_fixture(n = 200L)
  yf <- factor(ifelse(f$y == 1L, "Yes", "No"), levels = c("No", "Yes"))
  expect_error(mm_decision_curve(yf, f$p, 0.1, positive = "Maybe"),
               "does not carry")
  expect_error(mm_decision_curve(yf, f$p, 0.1, positive = "Maybe"),
               "misnamed")
  expect_error(mm_decision_curve(yf, f$p, 0.1, positive = NA),
               "one non-missing value")
})

test_that("D04 NA predictions are dropped and counted, not propagated", {
  skip_if_not_installed("dcurves")
  f <- mm_dc_fixture()
  pna <- f$p
  pna[1:5] <- NA
  o <- mm_decision_curve(f$y, pna, c(0.1, 0.3), positive = 1)
  expect_identical(o$n_dropped[1], 5L)
  expect_identical(o$n[1], length(f$y) - 5L)
  expect_false(anyNA(o$net_benefit_model))
  ref <- suppressMessages(dcurves_reference("pred", pna, f$y, c(0.1, 0.3)))
  expect_lt(max(abs(o$net_benefit_model - ref)), 1e-12)
})

test_that("D05 a threshold of 1 is refused instead of returning NaN", {
  f <- mm_dc_fixture(n = 200L)
  for (th in list(1, c(0.1, 1.5), numeric(0), c(0.1, NA), -0.1, "0.2")) {
    expect_error(mm_decision_curve(f$y, f$p, th, positive = 1),
                 "must be numbers in \\[0, 1\\)")
  }
  # 0 is a threshold and must stay one: it is treat-everybody.
  expect_equal(nrow(mm_decision_curve(f$y, f$p, 0, positive = 1)), 1L)
})

test_that("D06 an outcome that cannot be binary is refused by name", {
  f <- mm_dc_fixture(n = 300L)
  set.seed(3)
  three <- factor(sample(c("a", "b", "c"), length(f$y), TRUE))
  expect_error(mm_decision_curve(three, f$p, f$th), "cannot infer the event")
  cont <- stats::rnorm(length(f$y))
  expect_error(mm_decision_curve(cont, f$p, f$th), "cannot infer the event")
})

test_that("D07 one outcome class is refused: net benefit needs both", {
  f <- mm_dc_fixture(n = 200L)
  expect_error(mm_decision_curve(rep(1L, length(f$y)), f$p, f$th, positive = 1),
               "outcome class")
  # An outcome holding only non-events reaches the declared-level check first,
  # and that is the right order: it can report what the column actually holds.
  # The message must not assert a misnamed level, because a sample with no
  # events is the other reading and this cannot tell them apart.
  expect_error(mm_decision_curve(rep(0L, length(f$y)), f$p, f$th, positive = 1),
               "carries no events")
  expect_error(mm_decision_curve(rep(0L, length(f$y)), f$p, f$th, positive = 1),
               "It holds \"0\"")
  # Undeclared, an all-zero numeric outcome is already 0/1 so coercion lets it
  # through and the two-class rule below catches it instead.
  expect_error(mm_decision_curve(rep(0L, length(f$y)), f$p, f$th),
               "outcome class")
})

test_that("D08 ties exactly on the threshold follow dcurves' convention", {
  skip_if_not_installed("dcurves")
  f <- mm_dc_fixture()
  pt <- rep(0.3, length(f$y))
  ours <- mm_decision_curve(f$y, pt, 0.3, positive = 1)$net_benefit_model
  ref <- suppressMessages(dcurves_reference("pred", pt, f$y, 0.3))
  expect_lt(abs(ours - ref), 1e-12)
})

test_that("a linear predictor passed as a probability is refused", {
  # Added in the port. plogis() was applied by the caller in the source
  # project; here mm_predict() returns probabilities and fitted(scale = "link")
  # returns a linear predictor, so the two are a plausible mix-up and a
  # net benefit computed from one would be silently wrong rather than absurd.
  f <- mm_dc_fixture(n = 200L)
  expect_error(mm_decision_curve(f$y, f$lp, 0.2, positive = 1),
               "not a probability")
  expect_error(mm_decision_curve(f$y, f$p[1:10], 0.2, positive = 1),
               "200 outcome\\(s\\) against 10 prediction\\(s\\)")
  expect_error(mm_decision_curve(f$y, as.character(f$p), 0.2, positive = 1),
               "needs predicted probabilities")
})

test_that("the curve works end to end on a fitted model", {
  cohort <- mm_synthetic_cohort(n = 400, seed = 12)
  fit <- suppressWarnings(mm_model(
    mm_project("dca", "event", c("age", "bmi"), positive_class = 1,
               cohort = cohort), cohort))
  o <- mm_decision_curve(cohort$event, mm_predict(fit, cohort)$.pred,
                         thresholds = seq(0, 0.3, by = 0.05), positive = 1)
  expect_identical(nrow(o), 7L)
  expect_false(anyNA(o$net_benefit_model))
  # The model should not be beaten by treating everybody across the whole
  # range on its own development rows. This is apparent performance and is
  # not evidence the curve transports anywhere.
  expect_true(all(o$net_benefit_model >= o$net_benefit_all - 1e-9))
})
