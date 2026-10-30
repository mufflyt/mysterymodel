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

# The gate has to be told the sample that exists. `rms` drops a row with a
# missing model variable before fitting, so the rows handed to mm_model() and
# the rows it estimated on differ whenever the development data is incomplete.

holey_cohort <- function(n = 400, seed = 1978) {
  cohort <- mm_synthetic_cohort(n = n, seed = seed)
  cohort$bmi[1:40] <- NA
  cohort$age[200:209] <- NA
  cohort
}

# Warnings collected rather than matched one at a time, because this call
# raises two for different reasons and expect_warning() would let the other
# escape the test.
warnings_from <- function(expr) {
  seen <- character(0)
  withCallingHandlers(expr, warning = function(cond) {
    seen <<- c(seen, conditionMessage(cond))
    invokeRestart("muffleWarning")
  })
  seen
}

test_that("every count describes the rows fitted, not the rows supplied", {
  cohort <- holey_cohort()
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  # Computed from the cohort, not read back off the fit, so this fails if the
  # counts come from either the supplied frame or the wrong part of the fit.
  usable <- stats::complete.cases(
    cohort[, c("event", "age", "bmi", "sex")])
  expect_lt(sum(usable), nrow(cohort))

  expect_equal(model$n_dev, sum(usable))
  expect_equal(model$events_dev, sum(cohort$event[usable]))
  expect_equal(model$adequacy$n, sum(usable))
  expect_equal(model$adequacy$events, sum(cohort$event[usable]))
  expect_equal(model$n_supplied, nrow(cohort))
  expect_equal(model$n_incomplete, nrow(cohort) - sum(usable))
})

test_that("the dropped rows are named by the variable that cost them", {
  cohort <- holey_cohort()
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  expect_setequal(names(model$incomplete_by), c("age", "bmi"))
  expect_equal(unname(model$incomplete_by[["bmi"]]), 40L)
  expect_equal(unname(model$incomplete_by[["age"]]), 10L)

  # And the analyst is told, rather than left to compare two numbers nobody
  # printed. Deciding the analysis sample belongs in mm_clean().
  said <- warnings_from(mm_model(project, cohort, nonlinear = "age"))
  expect_true(any(grepl("dropped before fitting", said)))
  expect_true(any(grepl("mm_clean", said)))
})

test_that("judging the supplied rows would have been the lenient error", {
  # This is why the bug mattered rather than merely being wrong: the gate on
  # the larger, partly imaginary sample asks for less than the gate on the
  # sample that exists, so it is most forgiving where data is most incomplete.
  cohort <- holey_cohort()
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  as_supplied <- mm_adequacy(
    n = nrow(cohort),
    events = sum(mm_event_indicator(cohort$event, 1)),
    parameters = model$adequacy$parameters,
    nagelkerke = model$adequacy$nagelkerke,
    likelihood_ratio = unname(model$fit$stats[["Model L.R."]]))

  expect_gt(model$adequacy$short_by, as_supplied$short_by)
})

test_that("complete development data is unaffected", {
  cohort <- mm_synthetic_cohort(n = 500, seed = 1978)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  expect_equal(model$n_incomplete, 0L)
  expect_length(model$incomplete_by, 0L)
  expect_equal(model$n_dev, nrow(cohort))
  expect_equal(model$n_supplied, nrow(cohort))
  expect_no_warning(capture.output(print(model)))
})

test_that("a likelihood ratio rms never computed is reported, not raised", {
  # A fit that did not converge has no `Model L.R.` in its stats at all, so
  # the gate receives a length-zero value rather than NA. `||` on that raises
  # "missing value where TRUE/FALSE needed", which names nothing.
  for (absent in list(NULL, numeric(0))) {
    a <- mm_adequacy(n = 300, events = 30, parameters = 5,
                     nagelkerke = 0.1, likelihood_ratio = absent)
    expect_true(is.na(a$heuristic_shrinkage))
  }
})

test_that("the adequacy object records the assumption behind its requirement", {
  # `shrinkage` is the caller's to set, so the requirement is only meaningful
  # beside the target it was computed under. A stricter target asks for more.
  loose <- mm_adequacy(n = 500, events = 60, parameters = 8,
                       nagelkerke = 0.15, likelihood_ratio = 40,
                       shrinkage = 0.9)
  tight <- mm_adequacy(n = 500, events = 60, parameters = 8,
                       nagelkerke = 0.15, likelihood_ratio = 40,
                       shrinkage = 0.95)
  expect_equal(loose$target_shrinkage, 0.9)
  expect_equal(tight$target_shrinkage, 0.95)
  expect_gt(tight$required_n, loose$required_n)

  # The reported events per parameter is the observed one, computed here and
  # not taken from pmsampsize's required EPP, which is a different quantity.
  expect_equal(loose$events_per_parameter, 60 / 8)
})
