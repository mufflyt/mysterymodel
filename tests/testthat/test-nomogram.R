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

test_that("the tick profiles move one predictor at a time", {
  # Every tick of every axis is exercised without taking the product of them
  # all, factors come back as the fitted levels, and the row order follows the
  # predictors, because mm_nomogram() pairs these rows with mm_predict().
  cohort <- mm_synthetic_cohort(n = 400, seed = 1978)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  nom <- mm_nomogram(model, out_dir = NULL)
  vals <- mysterymodel:::mm_axis_values(nom$nomogram, project$predictors)

  ticks <- mysterymodel:::mm_tick_profiles(nom$nomogram, model)
  expect_equal(nrow(ticks), sum(lengths(vals)))
  expect_identical(names(ticks), project$predictors)
  expect_s3_class(ticks$sex, "factor")
  expect_identical(levels(ticks$sex), model$schema$predictors$sex$levels)

  base <- vapply(vals, function(v) as.character(v[1]), character(1))
  moved <- vapply(seq_len(nrow(ticks)), function(i)
    sum(vapply(names(base), function(p)
      !identical(as.character(ticks[[p]][i]), base[[p]]), logical(1))),
    integer(1))
  expect_true(all(moved <= 1L))
})

test_that("the sheet grows with the model instead of crushing it", {
  cohort <- mm_synthetic_cohort(n = 300, seed = 1)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  small <- suppressWarnings(mm_model(project, cohort))
  drawn <- suppressMessages(mm_nomogram(small, out_dir = NULL))

  # A small model keeps the shape the specification asks for.
  expect_equal(drawn$width, 13)
  expect_equal(drawn$height, 9)

  # A row does not get shorter when there are more of them, so the page grows.
  # Found on the ENT applicant model: 27 axes on the 9 inches that suited 3
  # printed row labels across their own tick marks, and the sheet was drawn,
  # verified and unreadable.
  many <- structure(as.list(seq_len(30)), names = paste0("v", 1:30))
  expect_gt(mm_nomogram_page(many)$height, 16)
  expect_equal(mm_nomogram_page(many, height = 9)$height, 9)

  # Width follows the longest printed name, which shares the left margin with
  # every row's leftmost tick label.
  long <- stats::setNames(list(1, 2), c("x", strrep("a", 60)))
  expect_gt(mm_nomogram_page(long)$width, 13)
})

test_that("risk ticks are evenly spaced on the drawn axis, not in probability", {
  # The sheet is linear in the linear predictor, so equal steps of
  # probability are not equal steps on paper. Over a wide linear predictor
  # the default ticks bunched into a seventh of the axis and overprinted.
  ticks <- mm_risk_ticks(c(-8, 7))
  expect_gte(length(ticks), 3)
  expect_true(all(ticks > 0 & ticks < 1))
  expect_false(is.unsorted(ticks))
  # Rounded to figures a reader would write down: a round number near zero,
  # a round complement near one, or two decimals in between.
  readable <- vapply(ticks, function(x)
    isTRUE(all.equal(x, signif(x, 1))) ||
      isTRUE(all.equal(1 - x, signif(1 - x, 1))) ||
      isTRUE(all.equal(x, round(x, 2))), logical(1))
  expect_true(all(readable))

  lp <- stats::qlogis(ticks)
  gaps <- diff(lp)
  expect_lt(max(gaps) / min(gaps), 1.6)

  # A degenerate axis asks for nothing rather than returning a single tick.
  expect_length(mm_risk_ticks(c(2, 2)), 0)
  expect_length(mm_risk_ticks(c(NA_real_, NA_real_)), 0)
})

test_that("choosing the ticks cannot change what the sheet agrees with", {
  cohort <- mm_synthetic_cohort(n = 300, seed = 1)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  spaced <- suppressMessages(mm_nomogram(fit, out_dir = NULL))
  fixed <- suppressMessages(
    mm_nomogram(fit, out_dir = NULL, fun_at = c(0.05, 0.1, 0.2, 0.3)))

  # Both are checked against mm_predict() and both pass; the ticks decide
  # which profiles are checked, not whether the sheet is allowed out.
  expect_lt(spaced$worst_disagreement, spaced$tolerance)
  expect_lt(fixed$worst_disagreement, fixed$tolerance)
  expect_equal(spaced$n_axes, fixed$n_axes)
})

test_that("printed level text is title cased without touching the fit's levels", {
  cohort <- mm_synthetic_cohort(n = 400, seed = 7)
  cohort$aoa <- factor(sample(c("member", "no AOA at school", "No response"),
                              nrow(cohort), replace = TRUE))
  project <- mm_project("uds", "event", c("age", "aoa"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  titled <- suppressMessages(mm_nomogram(fit, out_dir = NULL))
  asis <- suppressMessages(mm_nomogram(fit, out_dir = NULL,
                                       level_case = "asis"))

  expect_equal(sort(titled$drawn$aoa$aoa),
               sort(c("Member", "No AOA at School", "No Response")))
  expect_equal(sort(asis$drawn$aoa$aoa),
               sort(c("member", "no AOA at school", "No response")))

  # `nomogram` is the sheet that was checked and keeps the fit's own levels,
  # whichever way the printed copy is spelled. Anything computing from the
  # sheet reads that one.
  expect_equal(titled$nomogram$aoa$aoa, asis$nomogram$aoa$aoa)
  expect_true(all(titled$nomogram$aoa$aoa %in%
                    fit$schema$predictors$aoa$levels))

  # The spelling is a caption. The levels the model scores are untouched, and
  # the sheet is checked against mm_predict() before either is applied, so
  # both forms carry the same verdict.
  expect_equal(fit$schema$predictors$aoa$levels,
               sort(c("member", "no AOA at school", "No response")))
  expect_equal(titled$worst_disagreement, asis$worst_disagreement)
  expect_equal(titled$profiles_checked, asis$profiles_checked)
  expect_lt(titled$worst_disagreement, titled$tolerance)

  # A continuous axis carries numbers and is left alone.
  expect_true(is.numeric(titled$drawn$age$age))
})
