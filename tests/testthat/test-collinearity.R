# Collinearity, checked three ways, because each question misses what the
# others catch. The fixture is a predictor copied with noise: the fit succeeds
# and reports nothing, which is the case the module exists for.

mm_collin_fixture <- function(n = 400L, seed = 2L) {
  cohort <- mm_synthetic_cohort(n = n, seed = seed)
  set.seed(seed)
  cohort$age_copy <- cohort$age + stats::rnorm(n, 0, 0.4)
  project <- mm_project("collin", "event", c("age", "age_copy", "bmi"),
                        positive_class = 1, cohort = cohort)
  list(cohort = cohort, project = project,
       fit = suppressWarnings(mm_model(project, cohort)))
}

mm_clean_fixture <- function(n = 400L, seed = 6L) {
  cohort <- mm_synthetic_cohort(n = n, seed = seed)
  project <- mm_project("clean", "event", c("age", "bmi"),
                        positive_class = 1, cohort = cohort)
  list(cohort = cohort, project = project,
       fit = suppressWarnings(mm_model(project, cohort)))
}

test_that("a duplicated predictor is caught by all three diagnostics", {
  skip_if_not_installed("Hmisc")
  f <- mm_collin_fixture()
  preds <- f$cohort[, c("age", "age_copy", "bmi")]

  v <- mm_vif_check(f$fit)
  expect_false(v$ok)
  expect_true(all(c("age", "age_copy") %in% names(v$flagged)))
  expect_false("bmi" %in% names(v$flagged))
  expect_match(v$reason, "at or above 4")

  r <- mm_redun_check(preds)
  expect_false(r$ok)
  expect_identical(r$dropped, "age_copy")
  expect_match(r$reason, "in the order redun\\(\\) dropped them")

  p <- mm_cor_pairs(preds)
  expect_identical(nrow(p), 1L)
  expect_setequal(c(p$a, p$b), c("age", "age_copy"))
  expect_gt(abs(p$rho), 0.99)
})

test_that("an uncorrelated model reports clean on all three", {
  skip_if_not_installed("Hmisc")
  f <- mm_clean_fixture()
  expect_true(mm_vif_check(f$fit)$ok)
  expect_match(mm_vif_check(f$fit)$reason, "none at or above 4")
  expect_true(mm_redun_check(f$cohort[, c("age", "bmi")])$ok)
  expect_identical(nrow(mm_cor_pairs(f$cohort[, c("age", "bmi")])), 0L)
  rep <- mm_collinearity_report(f$fit, f$cohort)
  expect_true(rep$ok)
  expect_match(rep$text, "no numeric pair")
})

test_that("the three checks disagree by design, and the report runs all three", {
  # VIF is per PARAMETER and blind to a variable predictable from a
  # COMBINATION of others while correlating strongly with none; redundancy
  # asks exactly that question; the pair matrix names the pair a human can act
  # on. A report that ran only one of them would be the original defect, which
  # was running them once by hand.
  skip_if_not_installed("Hmisc")
  f <- mm_collin_fixture()
  rep <- mm_collinearity_report(f$fit, f$cohort)
  expect_false(rep$ok)
  expect_named(rep, c("vif", "redun", "pairs", "ok", "text"))
  expect_match(rep$text, "VIF:")
  expect_match(rep$text, "redundancy:")
  expect_match(rep$text, "pairs at")
  # The pair matrix is advisory and does not gate on its own.
  expect_identical(rep$ok, rep$vif$ok && rep$redun$ok)
})

test_that("the outcome is removed before redundancy and correlation", {
  # A predictor correlated with the OUTCOME is the point of the model, not a
  # problem with it. If the outcome stayed in the frame, a model that works
  # would report its own signal as redundancy.
  skip_if_not_installed("Hmisc")
  cohort <- mm_synthetic_cohort(n = 400, seed = 8)
  cohort$shadow <- as.numeric(cohort$event)
  project <- mm_project("shadow", "event", c("age", "bmi"),
                        positive_class = 1, cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  rep <- mm_collinearity_report(fit, cohort)
  # `shadow` is a copy of the outcome but is not a declared predictor, so it
  # is not in the frame these checks see at all.
  expect_false(grepl("shadow", rep$text))
  expect_false(grepl("event", rep$text))
  expect_true(rep$ok)
})

test_that("a cohort the model was not developed on is refused", {
  # mm_model() does not retain the rows it was fitted on, so the frame has to
  # be supplied, and collinearity measured on a different frame of the same
  # shape would describe a different sample while reading as though it
  # described the fit. The same refusal mm_validate() makes.
  f <- mm_clean_fixture()
  other <- f$cohort
  other$age[1] <- other$age[1] + 3
  expect_error(mm_collinearity_report(f$fit, other),
               "collinearity diagnostics")
  expect_error(mm_collinearity_report(f$fit, other), "fingerprint")
  expect_error(mm_collinearity_report(f$fit, f$cohort[-1, ]),
               "not the cohort the model was developed on")
})

test_that("each check refuses input it cannot answer for", {
  f <- mm_clean_fixture()
  expect_error(mm_vif_check(data.frame(a = 1)), "must be an mm_model")
  expect_error(mm_vif_check(f$fit, max = 1), "one number above 1")
  expect_error(mm_vif_check(f$fit, max = 0.5), "never below 1")
  expect_error(mm_vif_check(f$fit, max = c(2, 4)), "one number above 1")
  expect_error(mm_collinearity_report(f$fit$fit, f$cohort),
               "must come from mm_model")

  skip_if_not_installed("Hmisc")
  expect_error(mm_redun_check(f$cohort[, "age", drop = FALSE]),
               "two or more predictors")
  expect_error(mm_redun_check(f$cohort$age), "must be a data frame")
})

test_that("mm_cor_pairs is shaped the same whether or not it finds anything", {
  f <- mm_collin_fixture()
  empty <- mm_cor_pairs(f$cohort[, "age", drop = FALSE])
  expect_identical(names(empty), c("a", "b", "rho"))
  expect_identical(nrow(empty), 0L)
  # A factor is not a numeric pair, and a frame of only factors is the same
  # empty answer rather than an error.
  expect_identical(nrow(mm_cor_pairs(f$cohort[, "sex", drop = FALSE])), 0L)
  # SORTED BY ABSOLUTE CORRELATION, STRONGEST FIRST, and the fixture is built
  # so that the sort is observable. which(arr.ind = TRUE) walks the lower
  # triangle column by column, giving (2,1) before (4,3), so a WEAK first pair
  # and a STRONG last pair make the unsorted and sorted orders differ. An
  # earlier version of this block used a fixture whose natural order already
  # happened to be descending, so `expect_identical(p$rho, sort(p$rho))` held
  # with the sort removed: mutation MP12 survived it.
  set.seed(31)
  n <- 300
  d <- data.frame(v1 = stats::rnorm(n))
  d$v2 <- 0.25 * d$v1 + stats::rnorm(n)
  d$v3 <- stats::rnorm(n)
  d$v4 <- d$v3 + stats::rnorm(n, 0, 0.15)
  p <- mm_cor_pairs(d, max = 0.2)
  expect_identical(nrow(p), 2L)
  # Unsorted this is v2/v1 first at about 0.24; sorted it is v4/v3 at 0.98.
  expect_identical(c(p$a[1], p$b[1]), c("v4", "v3"))
  expect_gt(abs(p$rho[1]), abs(p$rho[2]))
  expect_identical(which.max(abs(p$rho)), 1L)
  expect_false(is.unsorted(rev(abs(p$rho))))
})

test_that("the VIF check accepts either an mm_model or the fit inside it", {
  f <- mm_clean_fixture()
  expect_equal(mm_vif_check(f$fit)$vif, mm_vif_check(f$fit$fit)$vif)
})
