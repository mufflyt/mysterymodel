# The between-tick reading error is reported as a bound, so the test that
# matters is that nothing a clinician could read exceeds it. Every check here
# searches for a counterexample rather than recording the figure.

bound_fixture <- function(nonlinear = c("age", "bmi"), interactions = NULL,
                          predictors = c("age", "bmi", "sex", "prior_uti"),
                          n = 600, seed = 1978) {
  cohort <- mm_synthetic_cohort(n = n, prevalence = 0.12, seed = seed)
  project <- mm_project("uds", "event", predictors, positive_class = 1,
                        cohort = cohort, seed = seed)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = nonlinear,
                                     interactions = interactions))
  list(model = model, nom = mm_nomogram(model, out_dir = NULL),
       project = project)
}

# Profiles anywhere inside the printed axes, which is where a clinician reads.
anywhere <- function(f, m, seed) {
  schema <- f$model$schema$predictors
  vals <- mysterymodel:::mm_axis_values(f$nom$nomogram, f$project$predictors)
  set.seed(seed)
  out <- lapply(names(schema), function(p) {
    if (identical(schema[[p]]$type, "numeric")) {
      stats::runif(m, min(vals[[p]]), max(vals[[p]]))
    } else {
      factor(sample(schema[[p]]$levels, m, TRUE), levels = schema[[p]]$levels)
    }
  })
  names(out) <- names(schema)
  as.data.frame(out, stringsAsFactors = FALSE)
}

worst_observed <- function(f, m = 3000, seed = 7) {
  frame <- anywhere(f, m, seed)
  read <- vapply(seq_len(nrow(frame)), function(i)
    mysterymodel:::mm_nomogram_risk(f$nom$nomogram, frame[i, , drop = FALSE]),
    numeric(1))
  max(abs(read - mm_predict(f$model, frame)$.pred), na.rm = TRUE)
}

test_that("no reading anywhere between the ticks exceeds the bound", {
  # The old figure varied one predictor at a time with the others at their
  # first tick, so it probed a few lines through one corner of the space and
  # was exceeded by ordinary profiles by factors of two to thirteen.
  for (f in list(bound_fixture(c("age", "bmi")),
                 bound_fixture("age"),
                 bound_fixture(c("age", "bmi"),
                               list(c("prior_uti", "sex"))))) {
    expect_gte(f$nom$reading_error, worst_observed(f))
  }
})

test_that("the bound holds when a spline interacts with a factor", {
  # rms draws one axis per level, each with its own points curve, so a scan of
  # a single stratum is not a bound over the others. On this fixture the two
  # strata differ by a factor of eight in one direction.
  f <- bound_fixture("age", list(c("age", "sex")),
                     predictors = c("age", "bmi", "sex"), n = 800)
  expect_length(grep("^age", mysterymodel:::mm_axis_names(f$nom$nomogram)), 2L)
  expect_gte(f$nom$reading_error, worst_observed(f))
})

test_that("the error is exactly zero where there is no curve to cut across", {
  # Linear terms make the printed points affine in the predictor, so the
  # interpolation is exact and the bound is not a small number but zero.
  f <- bound_fixture(nonlinear = NULL)
  expect_lt(f$nom$reading_error, 1e-12)
  expect_lt(worst_observed(f), 1e-12)
  expect_equal(unname(f$nom$reading_error_by_axis[, "lo"]),
               rep(0, nrow(f$nom$reading_error_by_axis)))

  # And a curve makes it strictly larger, which is the comparison the
  # nomogram article draws.
  curved <- bound_fixture("age")
  expect_gt(curved$nom$reading_error, f$nom$reading_error)
})

test_that("no axis to read between means no figure rather than zero", {
  cohort <- mm_synthetic_cohort(n = 400, seed = 1978)
  project <- mm_project("uds", "event", c("sex", "prior_uti"),
                        positive_class = 1, cohort = cohort)
  model <- suppressWarnings(mm_model(project, cohort))
  nom <- mm_nomogram(model, out_dir = NULL)
  expect_true(is.na(nom$reading_error))
  expect_true(is.na(nom$reading_error_lp))
  expect_null(nom$reading_error_by_axis)
  expect_no_error(capture.output(print(nom)))
})

test_that("the error decomposes per axis, and is zero at every tick", {
  # This is what makes a bound reachable without searching the joint space: the
  # discrepancy is b times the sum of per-axis interpolation errors, and each
  # of those vanishes at its own ticks.
  f <- bound_fixture(c("age", "bmi"))
  n <- f$nom$nomogram
  ticks <- mysterymodel:::mm_tick_profiles(n, f$model)
  reading <- vapply(seq_len(nrow(ticks)), function(i)
    mysterymodel:::mm_total_to_lp(
      n, mysterymodel:::mm_nomogram_points(n, ticks[i, , drop = FALSE])),
    numeric(1))
  at_ticks <- reading - stats::qlogis(mm_predict(f$model, ticks)$.pred)
  expect_lt(max(abs(at_ticks)), 1e-8)

  # Each axis's own range, and the lp bound as the sum of the extremes.
  by_axis <- f$nom$reading_error_by_axis
  expect_setequal(rownames(by_axis), c("age", "bmi"))
  expect_equal(f$nom$reading_error_lp,
               max(abs(sum(by_axis[, "lo"])), abs(sum(by_axis[, "hi"]))))
  # And the risk bound is that lp bound taken through the steepest part of the
  # logistic, which is where it is largest.
  d <- f$nom$reading_error_lp
  expect_equal(f$nom$reading_error,
               stats::plogis(d / 2) - stats::plogis(-d / 2))
  expect_gte(f$nom$reading_error,
             max(abs(stats::plogis(seq(-6, 6, by = 0.05) + d) -
                       stats::plogis(seq(-6, 6, by = 0.05)))))
})

test_that("the bound does not depend on how finely each gap is scanned", {
  # A finite grid makes this a numerical bound rather than an analytic one, so
  # its stability is the evidence that the grid is fine enough.
  f <- bound_fixture(c("age", "bmi"))
  coarse <- mysterymodel:::mm_reading_error(f$nom$nomogram, f$model,
                                            per_gap = 3L)
  fine <- mysterymodel:::mm_reading_error(f$nom$nomogram, f$model,
                                          per_gap = 25L)
  # Absolute, not relative: what matters is how much risk the slack is worth.
  expect_lt(abs(fine$bound - coarse$bound), 1e-4)
  expect_lt(abs(f$nom$reading_error - fine$bound), 1e-4)

  # A finer grid can only find a sharper extremum, so it does not come in
  # under a coarser one. This is the direction the slack runs in, and the
  # reason the figure is documented as numerical rather than analytic.
  expect_gte(fine$lp, coarse$lp)

  # The slack is an order of magnitude smaller than the margin by which the
  # bound already exceeds the worst reading anyone can take.
  expect_gt(f$nom$reading_error - worst_observed(f),
            10 * abs(fine$bound - coarse$bound))
})
