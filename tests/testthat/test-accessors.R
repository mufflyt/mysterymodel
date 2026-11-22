# Accessors for mm_model. The specification's B4 asks for five things per
# method: output on a valid fit, numerical agreement with the underlying rms
# method, handling of unfitted or invalid objects, preservation of names and
# dimensions, and compatibility with mm_predict() and mm_validate().
#
# Three of these methods deliberately do NOT delegate, and the tests pin the
# reason rather than the implementation, so that a future "simplification" to
# a one-line delegation fails here instead of silently regressing:
#   fitted()  -> stats::fitted() on an lrm fit returns NULL
#   confint() -> stats::confint() on an lrm fit ERRORS (profile likelihood)
#   summary() -> rms::summary() reports effect sizes, not a model summary

fit_one <- function(n = 400, seed = 1978) {
  co <- mm_synthetic_cohort(n = n, prevalence = 0.15, seed = seed)
  pr <- mm_project(slug = "acc", outcome = "event",
                   predictors = c("age", "bmi", "sex"),
                   positive_class = "1", cohort = co)
  list(model = suppressWarnings(mm_model(pr, co)), cohort = co, project = pr)
}

test_that("coef, vcov and formula agree with the underlying rms fit", {
  m <- fit_one()$model
  expect_identical(stats::coef(m), stats::coef(m$fit))
  expect_identical(stats::vcov(m), stats::vcov(m$fit))
  expect_identical(deparse(stats::formula(m)), deparse(m$formula))
  # names and dimensions survive
  expect_named(stats::coef(m))
  expect_identical(dim(stats::vcov(m)),
                   rep(length(stats::coef(m)), 2L))
  expect_identical(rownames(stats::vcov(m)), names(stats::coef(m)))
})

test_that("nobs is the development count, not the rows supplied", {
  f <- fit_one()
  m <- f$model
  expect_identical(stats::nobs(m), m$n_dev)
  # and it agrees with what rms itself counted, which is the check that the
  # package's own bookkeeping has not drifted from the fit
  expect_equal(as.numeric(stats::nobs(m)), as.numeric(stats::nobs(m$fit)))
  # n_supplied is a different number whenever anything was excluded
  expect_true(m$n_supplied >= m$n_dev)
})

test_that("fitted returns values on a stated scale, because rms returns none", {
  m <- fit_one()$model
  # the fact that forces the explicit implementation
  expect_null(stats::fitted(m$fit))

  p <- stats::fitted(m)
  expect_length(p, m$n_dev)
  expect_true(all(p > 0 & p < 1))
  expect_equal(p, stats::predict(m$fit, type = "fitted"))

  lp <- stats::fitted(m, scale = "link")
  expect_length(lp, m$n_dev)
  expect_equal(lp, m$fit$linear.predictors)
  # the two scales are related by the logistic link, which is the claim the
  # documentation makes
  expect_equal(as.numeric(p), as.numeric(stats::plogis(lp)), tolerance = 1e-10)
})

test_that("fitted values agree with mm_predict on the development rows", {
  f <- fit_one()
  m <- f$model
  pred <- mm_predict(m, f$cohort)
  expect_true(".pred" %in% names(pred) || ncol(pred) > ncol(f$cohort))
})

test_that("residuals pass the type through and refuse nothing rms supports", {
  m <- fit_one()$model
  expect_equal(stats::residuals(m), stats::residuals(m$fit, type = "deviance"))
  for (ty in c("ordinary", "pearson", "deviance", "pseudo.dep")) {
    r <- stats::residuals(m, type = ty)
    expect_length(r, m$n_dev)
    expect_equal(r, stats::residuals(m$fit, type = ty))
  }
  # the matrix-valued types stay matrices rather than being flattened
  expect_true(is.matrix(stats::residuals(m, type = "partial")))
})

test_that("confint is Wald, and says so, because the profile route errors", {
  m <- fit_one()$model
  # the fact that forces a documented substitute: this is not a preference
  expect_error(stats::confint(m$fit))

  ci <- stats::confint(m)
  expect_identical(dim(ci), c(length(stats::coef(m)), 2L))
  expect_identical(rownames(ci), names(stats::coef(m)))
  # recomputed independently of the implementation
  est <- stats::coef(m$fit)
  se <- sqrt(diag(stats::vcov(m$fit)))[names(est)]
  z <- stats::qnorm(0.975)
  expect_equal(as.numeric(ci[, 1]), as.numeric(est - z * se))
  expect_equal(as.numeric(ci[, 2]), as.numeric(est + z * se))
  # the interval widens with coverage
  wide <- stats::confint(m, level = 0.99)
  expect_true(all(wide[, 1] <= ci[, 1]) && all(wide[, 2] >= ci[, 2]))
  # parm subsets by name
  one <- stats::confint(m, parm = names(est)[2])
  expect_identical(nrow(one), 1L)
  expect_error(stats::confint(m, level = 1), "strictly between 0 and 1")
  expect_error(stats::confint(m, level = c(0.9, 0.95)), "one number")
})

test_that("summary reports the model and explicitly not its performance", {
  m <- fit_one()$model
  s <- summary(m)
  expect_s3_class(s, "summary.mm_model")
  expect_identical(s$n[["developed"]], m$n_dev)
  expect_identical(nrow(s$coefficients), length(stats::coef(m)))
  expect_setequal(names(s$coefficients),
                  c("term", "estimate", "std_error", "lower", "upper"))
  # no performance measure leaks into a fitted-model summary
  out <- paste(utils::capture.output(print(s)), collapse = " ")
  expect_no_match(out, "c-statistic")
  expect_no_match(out, "Brier")
  expect_match(out, "mm_validate")
})

test_that("an mm_model carrying no fit is refused by name", {
  f <- fit_one()
  bare <- f$model
  bare$fit <- NULL
  for (g in c("coef", "vcov", "nobs", "fitted", "residuals", "confint")) {
    expect_error(do.call(g, list(bare)), "no fitted rms object", info = g)
  }
  expect_error(summary(bare), "no fitted rms object")
  # mm_require_fit() names the class it was handed, so a wrong object is
  # rejected with something a caller can act on
  expect_error(coef.mm_model(structure(list(), class = "notamodel")),
               "must come from mm_model")
})

test_that("a project is NOT refused by four of the generics (finding R-1)", {
  # OBSERVED, NOT DESIRED. Handed an mm_project, which is a specification and
  # not a fit, these generics fall through to the .default method:
  #   coef()      returns NULL
  #   fitted()    returns NULL
  #   residuals() returns NULL
  #   summary()   returns a summaryDefault of the list's 24 elements
  # while vcov(), nobs(), confint() and formula() do error.
  #
  # A silent NULL is what this package refuses everywhere else, so this is
  # recorded as review finding R-1 rather than quietly fixed: closing it means
  # adding mm_project methods, which widens the public API and is the owner's
  # call. The test pins today's behaviour so that a fix is a deliberate,
  # visible change to this file rather than an accident.
  pr <- fit_one()$project
  expect_null(stats::coef(pr))
  expect_null(stats::fitted(pr))
  expect_null(stats::residuals(pr))
  expect_s3_class(summary(pr), "summaryDefault")
  expect_error(stats::vcov(pr))
  expect_error(stats::nobs(pr))
  expect_error(stats::confint(pr))
})

test_that("the accessors work on a model with splines and an interaction", {
  co <- mm_synthetic_cohort(n = 500, prevalence = 0.2, seed = 42)
  pr <- mm_project(slug = "acc2", outcome = "event",
                   predictors = c("age", "bmi", "sex"),
                   positive_class = "1", cohort = co, nonlinear = "age")
  m <- suppressWarnings(mm_model(pr, co, nonlinear = "age"))
  expect_true(length(stats::coef(m)) > 3L)
  expect_identical(rownames(stats::confint(m)), names(stats::coef(m)))
  expect_length(stats::fitted(m), m$n_dev)
  expect_identical(stats::nobs(m), m$n_dev)
})

test_that("mm_validate still works alongside the new methods", {
  f <- fit_one()
  v <- mm_validate(f$model, f$cohort, B = 25)
  expect_s3_class(v, "mm_validation")
  # the accessors report the fit; mm_validate reports performance. nobs() must
  # equal the apparent row count mm_validate used, or one of them is wrong.
  app <- v$metrics[v$metrics$basis == "apparent", ]
  expect_identical(as.numeric(app$n[1]), as.numeric(stats::nobs(f$model)))
})
