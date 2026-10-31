# The plan lives in the project, departures from it are visible, and the
# nomogram says what it can and cannot draw.

plan_cohort <- function(n = 900, prevalence = 0.18, seed = 1978) {
  mm_synthetic_cohort(n = n, prevalence = prevalence, seed = seed)
}

test_that("a project carries the shape it prespecifies", {
  cohort <- plan_cohort()
  project <- mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
                        positive_class = 1, cohort = cohort,
                        nonlinear = "age",
                        interactions = list(c("prior_uti", "sex")),
                        knots = 5L)
  expect_equal(project$nonlinear, "age")
  expect_equal(project$interactions, list(c("prior_uti", "sex")))
  expect_identical(project$knots, 5L)
  printed <- paste(capture.output(print(project)), collapse = " ")
  expect_match(printed, "spline on age, 5 knots")
  expect_match(printed, "prior_uti:sex")

  # And a project with no shape says so rather than leaving it blank.
  bare <- mm_project("uds", "event", c("age", "sex"), cohort = cohort)
  expect_null(bare$nonlinear)
  expect_match(paste(capture.output(print(bare)), collapse = " "),
               "every continuous predictor linear")
})

test_that("a plan that cannot be meant fails when it is written down", {
  cohort <- plan_cohort()
  expect_error(mm_project("uds", "event", c("age", "bmi"),
                          nonlinear = "weight"),
               "not predictors")
  expect_error(mm_project("uds", "event", c("age", "bmi"),
                          nonlinear = c("age", "age")),
               "one spline or none")
  expect_error(mm_project("uds", "event", c("age", "bmi"),
                          interactions = list(c("age", "age"))),
               "with itself")
  expect_error(mm_project("uds", "event", c("age", "bmi"),
                          interactions = list(c("age", "bmi"),
                                              c("bmi", "age"))),
               "more than once")
  expect_error(mm_project("uds", "event", c("age", "bmi"),
                          interactions = list(c("event", "age"))),
               "contains the outcome")
  expect_error(mm_project("uds", "event", c("age"),
                          interactions = list(c("age", "bmi"))),
               "needs its main effect")
  expect_error(mm_project("uds", "event", c("age"), nonlinear = "age",
                          knots = 2L),
               "at least 3")
})

test_that("mm_model follows the plan without being told", {
  cohort <- plan_cohort()
  planned <- mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
                        positive_class = 1, cohort = cohort,
                        nonlinear = "age",
                        interactions = list(c("prior_uti", "sex")))
  from_plan <- suppressWarnings(mm_model(planned, cohort))
  spelled_out <- suppressWarnings(
    mm_model(planned, cohort, nonlinear = "age",
             interactions = list(c("prior_uti", "sex"))))

  # Identical models, and neither counts as a departure.
  expect_identical(from_plan$fingerprint, spelled_out$fingerprint)
  expect_length(from_plan$departures, 0L)
  expect_length(spelled_out$departures, 0L)
  expect_match(deparse(from_plan$formula), "rcs(age, 4)", fixed = TRUE)
  expect_match(deparse(from_plan$formula), "prior_uti:sex", fixed = TRUE)
})

test_that("a departure from the plan is recorded and warned about", {
  cohort <- plan_cohort()
  planned <- mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
                        positive_class = 1, cohort = cohort,
                        nonlinear = "age")
  said <- character(0)
  departed <- withCallingHandlers(
    mm_model(planned, cohort, nonlinear = "bmi"),
    warning = function(w) {
      said <<- c(said, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_length(departed$departures, 1L)
  expect_match(departed$departures, "prespecifies age")
  expect_match(departed$departures, "used bmi")
  expect_true(any(grepl("departs from the project's written plan", said)))
  expect_match(paste(capture.output(print(departed)), collapse = " "),
               "DEPARTS")

  # Knots count as a departure only beside a declared spline.
  knotted <- withCallingHandlers(
    mm_model(planned, cohort, knots = 5L),
    warning = function(w) invokeRestart("muffleWarning"))
  expect_length(knotted$departures, 1L)
})

test_that("a project with no plan is not a project planning linearity", {
  # An unset field is unset. Reading it as a declaration of straight lines
  # would scold every existing call for departing from a default nobody set.
  cohort <- plan_cohort()
  bare <- mm_project("uds", "event", c("age", "bmi", "sex"),
                     positive_class = 1, cohort = cohort)
  quiet <- suppressWarnings(mm_model(bare, cohort, nonlinear = "age",
                                     knots = 5L))
  expect_length(quiet$departures, 0L)

  # No departure warning. Other warnings, such as the sample-size gate, are
  # none of this test's business, so they are collected rather than excluded.
  said <- character(0)
  withCallingHandlers(mm_model(bare, cohort, nonlinear = "age"),
                      warning = function(w) {
                        said <<- c(said, conditionMessage(w))
                        invokeRestart("muffleWarning")
                      })
  expect_false(any(grepl("departs from the project", said)))
})

test_that("a block crossing two continuous predictors is refused by name", {
  # It fits, it validates, mm_interactions() tests it, and rms cannot draw
  # it. The refusal used to arrive from inside rms naming an `interact`
  # argument the analyst never passed.
  cohort <- plan_cohort()
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort,
                        interactions = list(c("age", "bmi")))
  fitted <- suppressWarnings(mm_model(project, cohort))
  expect_s3_class(fitted, "mm_model")
  expect_false(is.na(suppressWarnings(
    mm_validate(fitted, cohort, B = 5))$metrics$c_stat[1]))

  expect_error(mm_nomogram(fitted, out_dir = NULL),
               "cannot be drawn as a nomogram")
  expect_error(mm_nomogram(fitted, out_dir = NULL),
               "crosses two continuous predictors")
  expect_error(mm_nomogram(fitted, out_dir = NULL), "as a calculator")
  # And not rms's own message, which names an argument the caller never used.
  raised <- tryCatch(mm_nomogram(fitted, out_dir = NULL),
                     error = function(e) conditionMessage(e))
  expect_false(grepl("interact=list", raised, fixed = TRUE))
  expect_match(raised, "mm_predict\\(\\) and mm_validate\\(\\) work")
})

test_that("every drawable interaction shape still draws", {
  cohort <- plan_cohort()
  shapes <- list(
    list(c("age", "bmi", "sex", "prior_uti"), list(c("prior_uti", "sex")),
         NULL),
    list(c("age", "sex", "indication"), list(c("sex", "indication")), NULL),
    list(c("age", "bmi", "sex"), list(c("age", "sex")), "age"))
  for (shape in shapes) {
    project <- mm_project("uds", "event", shape[[1]], positive_class = 1,
                          cohort = cohort, interactions = shape[[2]],
                          nonlinear = shape[[3]])
    fitted <- suppressWarnings(mm_model(project, cohort))
    nom <- mm_nomogram(fitted, out_dir = NULL)
    expect_lt(nom$worst_disagreement, 1e-6)
    expect_length(nom$exclusive_axes, 1L)
  }
})

test_that("mutually exclusive axes are named, with what chooses between them", {
  cohort <- plan_cohort()
  project <- mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
                        positive_class = 1, cohort = cohort,
                        interactions = list(c("prior_uti", "sex")))
  nom <- mm_nomogram(suppressWarnings(mm_model(project, cohort)),
                     out_dir = NULL)
  group <- nom$exclusive_axes[[1]]

  expect_setequal(group$axes,
                  c("sex (prior_uti=no)", "sex (prior_uti=yes)"))
  # Read on the axis that varies, chosen by the one each axis pins.
  expect_equal(group$read_on, "sex")
  expect_equal(group$separated_by, "prior_uti")
  expect_equal(nom$n_axes, 4L)
  expect_equal(nom$n_predictors, 4L)

  printed <- paste(capture.output(print(nom)), collapse = " ")
  expect_match(printed, "mutually exclusive")
  expect_match(printed, "double-count")

  # A model with no interaction has no such group to warn about.
  plain <- mm_project("uds", "event", c("age", "bmi", "sex"),
                      positive_class = 1, cohort = cohort)
  bare <- mm_nomogram(suppressWarnings(mm_model(plain, cohort)),
                      out_dir = NULL)
  expect_length(bare$exclusive_axes, 0L)
  expect_no_match(paste(capture.output(print(bare)), collapse = " "),
                  "mutually exclusive")
})
