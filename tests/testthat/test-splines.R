# What the two allocations imply, and never which one to choose.

sp_cohort <- function(n = 600, prevalence = 0.15, seed = 1978) {
  mm_synthetic_cohort(n = n, prevalence = prevalence, seed = seed)
}
sp_project <- function(cohort,
                       predictors = c("age", "bmi", "sex", "prior_uti")) {
  mm_project("uds", "event", predictors, positive_class = 1,
             cohort = cohort, seed = 1978)
}

test_that("both arms are the models mm_model would fit, and nothing else", {
  # The curves must be the package's own predictions from the two
  # allocations, so this recomputes them rather than trusting the object.
  cohort <- sp_cohort()
  project <- sp_project(cohort)
  shapes <- mm_splines(project, cohort, predictors = "age", plot = FALSE)

  straight <- suppressWarnings(mm_model(project, cohort))
  curved <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  profile <- shapes$reference[rep(1L, nrow(shapes$curves)), , drop = FALSE]
  profile$age <- shapes$curves$value

  expect_equal(shapes$curves$linear, mm_predict(straight, profile)$.pred)
  expect_equal(shapes$curves$spline, mm_predict(curved, profile)$.pred)
  expect_equal(shapes$summary$parameters_linear,
               length(stats::coef(straight$fit)) - 1L)
  expect_equal(shapes$summary$parameters_spline,
               length(stats::coef(curved$fit)) - 1L)
  expect_equal(shapes$summary$added_parameters, 2L)
})

test_that("the largest gap is the largest gap, at the value reported", {
  cohort <- sp_cohort()
  shapes <- mm_splines(sp_project(cohort), cohort, plot = FALSE)
  for (p in shapes$summary$predictor) {
    part <- shapes$curves[shapes$curves$predictor == p, ]
    row <- shapes$summary[shapes$summary$predictor == p, ]
    gap <- abs(part$spline - part$linear)
    expect_equal(row$largest_risk_gap, max(gap))
    expect_equal(row$at_value, part$value[which.max(gap)])
  }
})

test_that("the allocation matters more where the truth is curved", {
  # The fixture plants 0.0011 * (age - 62)^2 and a linear bmi term, so the
  # allocation should matter more for age. The claim is the ordering, not a
  # ratio: a ratio would be tuned to this cohort.
  cohort <- sp_cohort(n = 900, prevalence = 0.18)
  expect_true("age_sq" %in% names(attr(cohort, "truth")$coefficients))
  shapes <- mm_splines(sp_project(cohort), cohort, plot = FALSE)
  gap_for <- function(s, p) s$summary$largest_risk_gap[
    s$summary$predictor == p]
  expect_gt(gap_for(shapes, "age"), gap_for(shapes, "bmi"))

  # The mechanism, against a control where age enters linearly by
  # construction. The same measurement on the same model shape, and the
  # curvature is the only thing that changed.
  straightened <- cohort
  set.seed(4)
  linear_lp <- -2.6 + 0.045 * (straightened$age - 62) +
    0.045 * (straightened$bmi - 29)
  straightened$event <- stats::rbinom(nrow(straightened), 1L,
                                      stats::plogis(linear_lp))
  control <- mm_splines(sp_project(straightened), straightened,
                        plot = FALSE)
  expect_lt(gap_for(control, "age"), gap_for(shapes, "age"))
})

test_that("curves are adjusted to a profile that is reported", {
  cohort <- sp_cohort()
  project <- sp_project(cohort)
  shapes <- mm_splines(project, cohort, plot = FALSE)
  reference <- shapes$reference

  expect_equal(nrow(reference), 1L)
  expect_setequal(names(reference), project$predictors)
  # Median and most common level, computed here.
  dev <- cohort
  expect_equal(reference$age, stats::median(dev$age))
  expect_equal(reference$bmi, stats::median(dev$bmi))
  expect_equal(as.character(reference$sex),
               names(which.max(table(as.character(dev$sex)))))
  expect_s3_class(reference$sex, "factor")
  expect_identical(levels(reference$sex), levels(droplevels(dev$sex)))

  # An override moves the curves, which is the point of reporting it.
  moved <- mm_splines(project, cohort, predictors = "age",
                      at = list(sex = "male", prior_uti = "yes"),
                      plot = FALSE)
  expect_equal(as.character(moved$reference$sex), "male")
  base <- mm_splines(project, cohort, predictors = "age", plot = FALSE)
  expect_false(isTRUE(all.equal(moved$curves$spline, base$curves$spline)))
})

test_that("the comparison refuses what it cannot compare", {
  cohort <- sp_cohort()
  project <- sp_project(cohort)
  expect_error(mm_splines(project, cohort, predictors = "sex"),
               "needs a continuous predictor")
  expect_error(mm_splines(project, cohort, predictors = "weight"),
               "not predictors of this project")
  expect_error(mm_splines(project, cohort, at = list(sex = "other")),
               "not one of the levels")
  expect_error(mm_splines(project, cohort, at = list(nope = 1)),
               "does not declare")
  expect_error(mm_splines("not a project", cohort), "mm_project")

  # A project with no continuous predictor has no allocation to draw.
  flat <- mm_project("uds", "event", c("sex", "prior_uti"),
                     positive_class = 1, cohort = cohort)
  expect_error(mm_splines(flat, cohort), "no continuous predictor")
})

test_that("drawing is a side effect and the object stands without it", {
  cohort <- sp_cohort()
  project <- sp_project(cohort)
  quiet <- mm_splines(project, cohort, plot = FALSE)
  path <- file.path(tempdir(), "mm_splines_test.png")
  grDevices::png(path, width = 900, height = 600)
  drawn <- mm_splines(project, cohort, plot = TRUE)
  grDevices::dev.off()

  expect_true(file.exists(path))
  expect_gt(file.size(path), 5000)
  expect_equal(drawn$curves, quiet$curves)
  expect_equal(drawn$summary, quiet$summary)
  unlink(path)
})

test_that("it reports an allocation and recommends neither", {
  # The governing principle: no p-value, no test, no selection. Fitting a
  # spline, reading the aggregate nonlinear term and dropping back when it is
  # not significant makes the model's shape a function of the outcome, and
  # nothing downstream corrects that.
  cohort <- sp_cohort()
  shapes <- mm_splines(sp_project(cohort), cohort, plot = FALSE)
  expect_false(any(grepl("p_value|p\\.value|statistic|significant",
                         names(shapes$summary))))
  expect_false(any(grepl("recommend|prefer|better|should",
                         shapes$summary$note)))
  printed <- paste(capture.output(print(shapes)), collapse = " ")
  expect_match(printed, "tests\\s+nothing")
  expect_match(printed, "prespecified choice")

  # And it leaves no model behind: the default fit is unchanged by having
  # looked.
  before <- suppressWarnings(mm_model(sp_project(cohort), cohort))
  invisible(mm_splines(sp_project(cohort), cohort, plot = FALSE))
  after <- suppressWarnings(mm_model(sp_project(cohort), cohort))
  expect_identical(before$fingerprint, after$fingerprint)
})

test_that("a fitting failure is reported per predictor, not raised", {
  # A cohort too small for the splined arm must leave the object usable, with
  # the reason on the row rather than an error from the whole call.
  cohort <- sp_cohort(n = 60, prevalence = 0.1, seed = 5)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  shapes <- mm_splines(project, cohort, knots = 7L, plot = FALSE)
  expect_s3_class(shapes, "mm_splines")
  expect_equal(nrow(shapes$summary), 2L)
  failed <- is.na(shapes$summary$largest_risk_gap)
  if (any(failed)) {
    expect_match(shapes$summary$note[failed], "could not be fitted")
  } else {
    expect_true(all(shapes$summary$added_parameters > 0L))
  }
})

test_that("the two arms differ in one predictor, whatever the plan declares", {
  # Found on the Pima cohort. mm_project() carries the prespecified splines
  # since DEC-009, and mm_model() takes them when its argument is NULL, so
  # the linear arm of this comparison was the project's own splined model
  # whenever the project declared a spline on the predictor being compared.
  # Both arms were then identical and the reported risk gap was exactly zero:
  # the function said the allocation made no difference, for every cohort
  # whose plan had been written down.
  cohort <- sp_cohort(n = 700)
  predictors <- c("age", "bmi", "sex", "prior_uti")
  bare <- mm_project("uds", "event", predictors, positive_class = 1,
                     cohort = cohort, seed = 1978)
  declared <- mm_project("uds", "event", predictors, positive_class = 1,
                         cohort = cohort, seed = 1978, nonlinear = "age")

  from_bare <- mm_splines(bare, cohort, predictors = "age", plot = FALSE)
  from_plan <- mm_splines(declared, cohort, predictors = "age",
                          plot = FALSE)

  # The comparison must not depend on whether the plan happens to name it.
  expect_equal(from_plan$summary$largest_risk_gap,
               from_bare$summary$largest_risk_gap)
  expect_equal(from_plan$curves$linear, from_bare$curves$linear)
  expect_equal(from_plan$curves$spline, from_bare$curves$spline)
  expect_gt(from_plan$summary$largest_risk_gap, 0)
  expect_equal(from_plan$summary$added_parameters, 2L)

  # And a spline the plan declares on a different predictor is kept in both
  # arms, because everything but the predictor under comparison is held as
  # specified.
  two <- mm_project("uds", "event", predictors, positive_class = 1,
                    cohort = cohort, seed = 1978,
                    nonlinear = c("age", "bmi"))
  both <- mm_splines(two, cohort, predictors = "age", plot = FALSE)
  one <- mm_splines(bare, cohort, predictors = "age", plot = FALSE)
  expect_equal(both$summary$parameters_linear,
               one$summary$parameters_linear + 2L)
  expect_equal(both$summary$added_parameters, 2L)

  # Declaring the plan is not a departure when mm_splines names the arms.
  expect_no_warning(invisible(mm_splines(declared, cohort,
                                         predictors = "age", plot = FALSE)))
})
