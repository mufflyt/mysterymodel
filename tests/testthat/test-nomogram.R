# The specification's nomogram contract: the drawn nomogram must reproduce
# the model it was drawn from, checked numerically at defined profiles. A
# nomogram that disagrees is a published instrument giving wrong risks.

nom_fixture <- function(..., n = 400, seed = 1978) {
  cohort <- mm_synthetic_cohort(n = n, seed = seed)
  project <- mm_project("uds", "event",
                        c("age", "bmi", "sex", "prior_uti"),
                        cohort = cohort)
  # These fixtures are small for speed, so the adequacy warning fires by
  # design. It is tested on its own in test-sample-size.R; here it would
  # only drown the nomogram failures this file exists to show.
  list(cohort = cohort,
       model = suppressWarnings(mm_model(project, cohort, ...)))
}

test_that("a linear nomogram reads back exactly", {
  f <- nom_fixture()
  nom <- mm_nomogram(f$model, out_dir = NULL)
  expect_lt(nom$worst_disagreement, 1e-10)
})

test_that("a spline nomogram reads back exactly at its ticks", {
  f <- nom_fixture(nonlinear = "age")
  nom <- mm_nomogram(f$model, out_dir = NULL)
  expect_lt(nom$worst_disagreement, 1e-10)
})

test_that("an interaction nomogram reads back exactly", {
  # rms emits mutually exclusive axes here, such as sex (prior_uti=no) and
  # sex (prior_uti=yes). Exactly one applies to any patient, so a reader
  # that summed both would double count and one that picked neither would
  # drop the term.
  f <- nom_fixture(nonlinear = "age",
                   interactions = list(c("prior_uti", "sex")))
  nom <- mm_nomogram(f$model, out_dir = NULL)
  expect_true(any(grepl("prior_uti=", nom$axes)))
  expect_lt(nom$worst_disagreement, 1e-10)
})

test_that("reading between ticks is zero error only without splines", {
  # Linear interpolation across a straight line is exact. Across a spline it
  # is not, and that error belongs to every printed nomogram.
  straight <- mm_nomogram(nom_fixture()$model, out_dir = NULL)
  curved <- mm_nomogram(nom_fixture(nonlinear = "age")$model,
                        out_dir = NULL)
  expect_lt(straight$reading_error, 1e-10)
  expect_gt(curved$reading_error, straight$reading_error)
})

test_that("the points-to-lp mapping is affine, and checked", {
  f <- nom_fixture(nonlinear = "age")
  old <- options(datadist = f$model$datadist)
  on.exit(options(old), add = TRUE)
  nom <- rms::nomogram(f$model$fit, fun = stats::plogis,
                       funlabel = "Predicted risk")
  # Two points on the printed axis define the line; every other tabulated
  # point must sit on it, or the reader's arithmetic does not hold.
  lp_at <- vapply(nom$lp$x, function(tp) mm_total_to_lp(nom, tp), numeric(1))
  expect_equal(lp_at, nom$lp$x.real, tolerance = 1e-10)
})

test_that("a total below the printed axis is still read correctly", {
  # The printed axis need not reach zero points. Clamping at its lowest tick
  # silently returns that tick's risk, which is a wrong answer that looks
  # like a right one.
  f <- nom_fixture(nonlinear = "age",
                   interactions = list(c("prior_uti", "sex")))
  nom <- mm_nomogram(f$model, out_dir = NULL)
  expect_lt(nom$worst_disagreement, 1e-10)
  expect_true(is.numeric(nom$off_axis))
})

test_that("export writes vector and raster files", {
  f <- nom_fixture()
  out <- file.path(tempdir(), paste0("nom", as.integer(runif(1, 1, 1e6))))
  nom <- suppressMessages(mm_nomogram(f$model, out_dir = out))
  expect_true(any(grepl("\\.pdf$", nom$files)))
  expect_true(all(file.exists(nom$files)))
  expect_true(all(file.size(nom$files) > 1000))
})

test_that("one profile builder serves both the tick check and the midpoints", {
  # The two readings are compared with each other, so they have to be built
  # the same way. This asserts the shape they share rather than the numbers:
  # one predictor moves, the rest sit at their first tabulated value, factors
  # come back as the fitted levels and the row order follows the predictors.
  cohort <- mm_synthetic_cohort(n = 400, seed = 1978)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  nom <- mm_nomogram(model, out_dir = NULL)
  vals <- mysterymodel:::mm_axis_values(nom$nomogram, project$predictors)

  ticks <- mysterymodel:::mm_profiles(vals, identity, model$schema)
  expect_identical(ticks,
                   mysterymodel:::mm_tick_profiles(nom$nomogram, model))
  expect_equal(nrow(ticks), sum(lengths(vals)))
  expect_identical(names(ticks), project$predictors)
  expect_s3_class(ticks$sex, "factor")
  expect_identical(levels(ticks$sex), model$schema$predictors$sex$levels)

  # Exactly one predictor differs from the base profile in every row.
  base <- vapply(vals, function(v) as.character(v[1]), character(1))
  moved <- vapply(seq_len(nrow(ticks)), function(i)
    sum(vapply(names(base), function(p)
      !identical(as.character(ticks[[p]][i]), base[[p]]), logical(1))),
    integer(1))
  expect_true(all(moved <= 1L))

  # A picker that selects nothing gives no frame rather than an empty one,
  # which is what mm_reading_error() reports as an absent figure.
  expect_null(mysterymodel:::mm_profiles(vals, function(v) numeric(0),
                                         model$schema))
  categorical <- mm_project("uds", "event", c("sex", "prior_uti"),
                            positive_class = 1, cohort = cohort)
  flat <- suppressWarnings(mm_model(categorical, cohort))
  expect_true(is.na(mm_nomogram(flat, out_dir = NULL)$reading_error))
})
