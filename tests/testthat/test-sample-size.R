# Fixture 2 of the specification's suite: a small, sparse-event cohort must
# warn on an overly ambitious parameter count rather than fit it quietly.

test_that("a sparse-event cohort with many parameters warns", {
  cohort <- mm_synthetic_cohort(n = 300, prevalence = 0.08, seed = 11)
  project <- mm_project("uds", "event",
                        c("age", "bmi", "sex", "prior_uti", "indication"),
                        cohort = cohort)
  expect_warning(
    mm_model(project, cohort, nonlinear = c("age", "bmi")),
    "too small for this model")
})

test_that("a frugal model on a large cohort does not warn", {
  cohort <- mm_synthetic_cohort(n = 6000, prevalence = 0.25, seed = 7)
  project <- mm_project("uds", "event", c("age", "sex"), cohort = cohort)
  expect_no_warning(model <- mm_model(project, cohort))
  expect_true(model$adequacy$adequate)
})

test_that("the report carries every quantity section 19 asks for", {
  cohort <- mm_synthetic_cohort(n = 500, seed = 1978)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        cohort = cohort)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  a <- model$adequacy
  for (field in c("n", "events", "prevalence", "parameters",
                  "events_per_parameter", "heuristic_shrinkage",
                  "required_n", "nagelkerke")) {
    expect_false(is.null(a[[field]]), info = field)
  }
})

test_that("spline and interaction terms are counted as parameters", {
  # These are the terms spent without being noticed, so a count that missed
  # them would clear exactly the models that most need the warning.
  cohort <- mm_synthetic_cohort(n = 2000, seed = 4)
  project <- mm_project("uds", "event",
                        c("age", "bmi", "sex", "prior_uti"),
                        cohort = cohort)
  plain <- suppressWarnings(mm_model(project, cohort))
  curved <- suppressWarnings(
    mm_model(project, cohort, nonlinear = "age",
             interactions = list(c("prior_uti", "sex"))))
  expect_gt(curved$adequacy$parameters, plain$adequacy$parameters)
})

test_that("events per parameter is reported but is not the criterion", {
  # A cohort can clear ten events per parameter and still be inadequate on
  # the Riley requirement, which is the point of not gating on the old rule.
  a <- mm_adequacy(n = 400, events = 120, parameters = 10,
                   nagelkerke = 0.02, likelihood_ratio = 12)
  expect_gt(a$events_per_parameter, 10)
  expect_false(a$adequate)
})

test_that("shrinkage is the fraction of signal not spent on parameters", {
  a <- mm_adequacy(n = 1000, events = 200, parameters = 5,
                   nagelkerke = 0.1, likelihood_ratio = 50)
  expect_equal(a$heuristic_shrinkage, (50 - 5) / 50)
})

test_that("an uncomputable requirement is reported, not guessed", {
  a <- mm_adequacy(n = 100, events = 0, parameters = 3,
                   nagelkerke = NA_real_)
  expect_false(a$adequate)
  expect_match(a$reason, "could not be computed")
})
