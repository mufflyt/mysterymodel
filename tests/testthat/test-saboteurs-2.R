# Saboteurs for everything added after the first twenty: the interaction
# screen, the spline comparison, the written plan, the drawn sheet's
# exclusive axes, and the separation check. Same rule as the first file: each
# breaks something on purpose and asserts the safeguard notices, and the
# comment says what a reader would have believed without it.

s2_cohort <- function(n = 700, prevalence = 0.16, seed = 1978) {
  mm_synthetic_cohort(n = n, prevalence = prevalence, seed = seed)
}
s2_project <- function(cohort, ...) {
  mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
             positive_class = 1, cohort = cohort, seed = 1978, ...)
}
s2_health <- function(risk) {
  structure(list(fit = list(linear.predictors = stats::qlogis(risk),
                            fail = FALSE,
                            coefficients = c(`(Intercept)` = 0.1, x = 0.3))),
            class = "mm_model")
}

# ---- the interaction screen ------------------------------------------------

test_that("saboteur: a deviance edited after fitting is caught by the cross-check", {
  # The LR statistic is a difference of deviances. If one of them drifts, the
  # number is wrong by exactly that drift and still looks like a chi-square.
  # rms's own LR table is the second opinion that says so.
  cohort <- s2_cohort()
  project <- s2_project(cohort)
  base <- suppressWarnings(mm_model(project, cohort))
  full <- suppressWarnings(mm_model(project, cohort,
                                    interactions = list(c("prior_uti",
                                                          "sex"))))
  honest <- unname(base$fit$deviance[2]) - unname(full$fit$deviance[2])

  drifted <- base
  drifted$fit$deviance[2] <- drifted$fit$deviance[2] + 5
  forged <- unname(drifted$fit$deviance[2]) - unname(full$fit$deviance[2])
  expect_equal(forged - honest, 5, tolerance = 1e-8)

  # The screen computes both and records whether they agree, so the forged
  # statistic cannot pass as the answer.
  screen <- suppressMessages(mm_interactions(project, cohort,
                                             list(c("prior_uti", "sex"))))
  expect_true(screen$screen$lr_agrees)
  expect_equal(screen$screen$statistic, honest, tolerance = 1e-8)
  expect_false(isTRUE(all.equal(screen$screen$statistic, forged)))
})

test_that("saboteur: a Wald statistic passed off as a likelihood ratio differs", {
  # They are different tests on the same block. If the label and the
  # arithmetic were ever swapped, the number would move, which is what makes
  # the label checkable rather than decorative.
  cohort <- s2_cohort()
  project <- s2_project(cohort)
  pair <- list(c("prior_uti", "sex"))
  lr <- suppressMessages(mm_interactions(project, cohort, pair))$screen
  wald <- suppressMessages(mm_interactions(project, cohort, pair,
                                           test = "Wald"))$screen
  expect_equal(lr$test_method, "LR")
  expect_equal(wald$test_method, "Wald")
  expect_false(isTRUE(all.equal(lr$statistic, wald$statistic)))
  expect_equal(lr$degrees_freedom, wald$degrees_freedom)
})

test_that("saboteur: a block made aliased only by which rows are eligible", {
  # Identifiability is a property of the rows that get fitted, not of the
  # column. The same `flag` column is estimable in one cohort and a copy of a
  # main effect in another that differs only in which rows are complete.
  whole <- s2_cohort()
  whole$flag <- factor("no", levels = c("no", "yes"))
  whole$flag[whole$sex == "male"][1:30] <- "yes"
  whole$flag[whole$sex == "female"][1:20] <- "yes"
  project <- mm_project("uds", "event", c("age", "bmi", "sex", "flag"),
                        positive_class = 1, cohort = whole, seed = 1978)
  expect_true(mysterymodel:::mm_interaction_rank(
    project, whole, c("sex", "flag"))$identifiable)

  # Now the women carrying the flag have no bmi, so eligibility removes them
  # and only men carry it. model.matrix() drops incomplete rows itself, which
  # is what makes the rank check describe the fitted sample either way.
  holey <- whole
  holey$bmi[holey$sex == "female" & holey$flag == "yes"] <- NA
  expect_false(mysterymodel:::mm_interaction_rank(
    project, holey, c("sex", "flag"))$identifiable)

  screen <- suppressMessages(mm_interactions(project, holey,
                                             list(c("sex", "flag"))))
  expect_equal(screen$screen$status, "not_estimable")
  expect_true(is.na(screen$screen$p_value))
  expect_match(screen$screen$reason, "no dimension")
})

test_that("saboteur: a forged convergence flag does not hide separation", {
  # fit$fail is a flag rms sets. The separation check reads the fitted values
  # instead, so a flag that says the fit is fine cannot make a likelihood
  # with no maximum look like one that has one.
  y <- c(0L, 0L, 0L, 1L, 1L, 1L)
  forged <- s2_health(c(0.41, 0.44, 0.49, 0.51, 0.55, 0.60))
  expect_false(isTRUE(forged$fit$fail))
  health <- mysterymodel:::mm_interaction_health(forged, y)
  expect_true(health$complete_separation)
  expect_true(health$converged)
  expect_match(health$note, "no interior maximum")
})

test_that("saboteur: fitted values reordered against the outcome change the verdict", {
  # Separation is a property of the pairing, not of the two marginal
  # distributions. Shuffling which patient has which risk leaves both
  # marginals identical and must change the answer.
  y <- c(0L, 0L, 0L, 1L, 1L, 1L)
  risk <- c(0.41, 0.44, 0.49, 0.51, 0.55, 0.60)
  expect_true(mysterymodel:::mm_interaction_health(
    s2_health(risk), y)$complete_separation)
  expect_false(mysterymodel:::mm_interaction_health(
    s2_health(rev(risk)), y)$complete_separation)
  expect_setequal(risk, rev(risk))
})

test_that("saboteur: a candidate budget that counts survivors understates the search", {
  # The complexity spent is the complexity considered. A budget reported
  # after screening would make a three-block search look like whichever
  # block came out of it.
  cohort <- s2_cohort()
  project <- s2_project(cohort)
  blocks <- list(c("prior_uti", "sex"), c("age", "bmi"), c("age", "sex"))
  screen <- suppressMessages(mm_interactions(project, cohort, blocks))
  expect_equal(screen$n_candidates, 3L)
  expect_equal(screen$candidate_parameters, sum(screen$screen$added_parameters))
  expect_equal(screen$candidate_parameters, 3L)

  one_only <- suppressMessages(mm_interactions(project, cohort, blocks[1]))
  expect_lt(one_only$candidate_parameters, screen$candidate_parameters)
})

test_that("saboteur: an outcome permuted before screening moves the evidence", {
  # A statistic that survived permutation would be measuring the design
  # rather than the association.
  cohort <- s2_cohort()
  project <- s2_project(cohort)
  real <- suppressMessages(mm_interactions(project, cohort,
                                           list(c("prior_uti", "sex"))))
  shuffled <- cohort
  set.seed(4)
  shuffled$event <- sample(shuffled$event)
  permuted <- suppressMessages(mm_interactions(project, shuffled,
                                               list(c("prior_uti", "sex"))))
  expect_false(isTRUE(all.equal(real$screen$statistic,
                                permuted$screen$statistic)))
  expect_equal(real$screen$added_rank, permuted$screen$added_rank)
})

# ---- the written plan ------------------------------------------------------

test_that("saboteur: a plan edited after it was written is still checked", {
  # mm_project() validates the plan it is given. Editing the field afterwards
  # bypasses that, so mm_model() checks again rather than trusting the object
  # it was handed.
  cohort <- s2_cohort()
  project <- s2_project(cohort)
  project$nonlinear <- "weight"
  expect_error(mm_model(project, cohort), "not predictors")

  doubled <- s2_project(cohort)
  doubled$interactions <- list(c("age", "sex"), c("sex", "age"))
  expect_error(suppressWarnings(mm_model(doubled, cohort)),
               "listed more than once")

  selfish <- s2_project(cohort)
  selfish$interactions <- list(c("age", "age"))
  expect_error(suppressWarnings(mm_model(selfish, cohort)),
               "with itself")
})

test_that("saboteur: a block smuggled past the plan into the outcome is refused", {
  cohort <- s2_cohort()
  project <- s2_project(cohort)
  project$interactions <- list(c("event", "sex"))
  expect_error(suppressWarnings(mm_model(project, cohort)),
               "main effect")
})

test_that("saboteur: a departure cannot be silent", {
  # A fit whose shape differs from the plan is a finding. Without the record
  # a reader comparing the printed formula to the protocol would have to
  # notice the difference themselves.
  cohort <- s2_cohort()
  planned <- s2_project(cohort, nonlinear = "age")
  said <- character(0)
  departed <- withCallingHandlers(
    mm_model(planned, cohort, nonlinear = "bmi"),
    warning = function(w) {
      said <<- c(said, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_length(departed$departures, 1L)
  expect_true(any(grepl("departs from the project", said)))
  expect_match(paste(capture.output(print(departed)), collapse = " "),
               "DEPARTS")
  # The model really is the departed one, not the plan.
  expect_match(deparse(departed$formula), "rcs(bmi", fixed = TRUE)
  expect_false(grepl("rcs(age", deparse(departed$formula), fixed = TRUE))
})

# ---- the spline comparison -------------------------------------------------

test_that("saboteur: a reference profile off the fitted levels is refused", {
  # Both curves are adjusted to that profile. A level the model never saw
  # would make them adjusted to nothing.
  cohort <- s2_cohort()
  project <- s2_project(cohort)
  expect_error(mm_splines(project, cohort, at = list(sex = "unrecorded")),
               "not one of the levels")
  expect_error(mm_splines(project, cohort, at = list(weight = 80)),
               "does not declare")
})

test_that("saboteur: the spline gap is computed from two arms, not asserted", {
  # If the two arms were ever the same model, the gap would be zero and the
  # comparison would quietly say the allocation does not matter.
  cohort <- s2_cohort()
  project <- s2_project(cohort)
  shapes <- mm_splines(project, cohort, predictors = "age", plot = FALSE)
  straight <- suppressWarnings(mm_model(project, cohort))
  curved <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  expect_false(identical(straight$fingerprint, curved$fingerprint))
  expect_gt(shapes$summary$largest_risk_gap, 0)
  expect_equal(shapes$summary$largest_risk_gap,
               max(abs(shapes$curves$spline - shapes$curves$linear)))
  # And the two columns are not the same numbers.
  expect_false(isTRUE(all.equal(shapes$curves$linear,
                                shapes$curves$spline)))
})

test_that("saboteur: a curve drawn at a moved profile is a different curve", {
  # An adjusted curve that did not move with its profile would be adjusted to
  # something other than what is reported.
  cohort <- s2_cohort()
  project <- s2_project(cohort)
  here <- mm_splines(project, cohort, predictors = "age", plot = FALSE)
  there <- mm_splines(project, cohort, predictors = "age",
                      at = list(prior_uti = "yes", sex = "male"),
                      plot = FALSE)
  expect_false(isTRUE(all.equal(here$curves$spline, there$curves$spline)))
  expect_equal(here$curves$value, there$curves$value)
  expect_equal(as.character(there$reference$prior_uti), "yes")
})

# ---- the drawn sheet -------------------------------------------------------

test_that("saboteur: axes grouped by label rather than by variables mislead", {
  # Two axes are mutually exclusive because they carry the same variables,
  # not because their printed labels look alike. Grouping on the label would
  # pair up axes that both apply.
  cohort <- s2_cohort()
  project <- s2_project(cohort, interactions = list(c("prior_uti", "sex")))
  model <- suppressWarnings(mm_model(project, cohort))
  nom <- mm_nomogram(model, out_dir = NULL)
  group <- nom$exclusive_axes[[1]]
  expect_setequal(group$variables, c("prior_uti", "sex"))

  renamed <- nom$nomogram
  names(renamed)[names(renamed) == "bmi"] <- "sex (prior_uti=maybe)"
  regrouped <- mysterymodel:::mm_exclusive_axes(renamed, model)
  # The renamed axis still carries only bmi, so it joins no group.
  expect_equal(length(regrouped), 1L)
  expect_false("sex (prior_uti=maybe)" %in% regrouped[[1]]$axes)
})

test_that("saboteur: an axis that varies its held variable is not a stratum", {
  # `separated_by` names the variable each axis pins. If one of them varied,
  # the axes would not be mutually exclusive and naming it would be wrong.
  cohort <- s2_cohort()
  project <- s2_project(cohort, interactions = list(c("prior_uti", "sex")))
  model <- suppressWarnings(mm_model(project, cohort))
  nom <- mm_nomogram(model, out_dir = NULL)
  group <- nom$exclusive_axes[[1]]
  expect_equal(group$separated_by, "prior_uti")

  # That axis pins prior_uti as a single value, which is what makes it a
  # stratum. Giving it two makes the axis apply to both, so it is no longer
  # the thing that chooses between them.
  axis <- group$axes[1]
  expect_length(nom$nomogram[[axis]]$prior_uti, 1L)
  tampered <- nom$nomogram
  tampered[[axis]]$prior_uti <- c("no", "yes")
  after <- mysterymodel:::mm_exclusive_axes(tampered, model)
  expect_length(after, 1L)
  expect_false(identical(after[[1]]$separated_by, "prior_uti"))
  expect_length(after[[1]]$separated_by, 0L)
})

test_that("saboteur: a continuous predictor disguised as categorical is still undrawable", {
  # The refusal reads the schema, which records what the model was fitted
  # with. A pair that is continuous there cannot be drawn whatever a label
  # says.
  cohort <- s2_cohort()
  project <- s2_project(cohort, interactions = list(c("age", "bmi")))
  model <- suppressWarnings(mm_model(project, cohort))
  expect_length(mysterymodel:::mm_undrawable_blocks(model), 1L)
  expect_error(mm_nomogram(model, out_dir = NULL),
               "crosses two continuous predictors")

  disguised <- model
  disguised$schema$predictors$bmi$type <- "categorical"
  expect_length(mysterymodel:::mm_undrawable_blocks(disguised), 0L)
  # Which is why the schema is built from the fitted frame and not supplied.
  expect_equal(model$schema$predictors$bmi$type, "numeric")
})

test_that("saboteur: a flattened axis understates the reading bound", {
  # The bound is the sum of each axis's worst interpolation error. An axis
  # whose points were straightened contributes nothing, and the bound would
  # then promise more than the drawn sheet delivers.
  cohort <- s2_cohort()
  project <- s2_project(cohort, nonlinear = "age")
  model <- suppressWarnings(mm_model(project, cohort))
  nom <- mm_nomogram(model, out_dir = NULL)
  honest <- mysterymodel:::mm_reading_error(nom$nomogram, model)
  expect_gt(honest$lp, 0)

  flattened <- nom$nomogram
  axis <- grep("^age", mysterymodel:::mm_axis_names(flattened), value = TRUE)[1]
  element <- flattened[[axis]]
  flattened[[axis]]$points <- seq(min(element$points), max(element$points),
                                  length.out = length(element$points))
  straightened <- mysterymodel:::mm_reading_error(flattened, model)
  expect_false(isTRUE(all.equal(straightened$lp, honest$lp)))
})

test_that("saboteur: a tick moved off its own value breaks the zero-at-ticks property", {
  # The bound rests on each axis's error vanishing at its own ticks, which is
  # what makes the extremes of the sum the sums of the extremes. If a tick
  # were not where the axis says, that property would fail silently.
  cohort <- s2_cohort()
  project <- s2_project(cohort, nonlinear = "age")
  model <- suppressWarnings(mm_model(project, cohort))
  nom <- mm_nomogram(model, out_dir = NULL)
  ticks <- mysterymodel:::mm_tick_profiles(nom$nomogram, model)
  at_ticks <- vapply(seq_len(nrow(ticks)), function(i)
    mysterymodel:::mm_total_to_lp(nom$nomogram,
      mysterymodel:::mm_nomogram_points(nom$nomogram,
                                        ticks[i, , drop = FALSE])),
    numeric(1)) - stats::qlogis(mm_predict(model, ticks)$.pred)
  expect_lt(max(abs(at_ticks)), 1e-8)

  moved <- nom$nomogram
  axis <- grep("^age", mysterymodel:::mm_axis_names(moved), value = TRUE)[1]
  moved[[axis]]$age[2] <- moved[[axis]]$age[2] + 6
  shifted <- vapply(seq_len(nrow(ticks)), function(i)
    mysterymodel:::mm_total_to_lp(moved,
      mysterymodel:::mm_nomogram_points(moved, ticks[i, , drop = FALSE])),
    numeric(1)) - stats::qlogis(mm_predict(model, ticks)$.pred)
  expect_gt(max(abs(shifted)), 1e-8)
})

# ---- discrimination and its interval --------------------------------------

test_that("saboteur: a zero-width interval cannot be reported as precision", {
  cohort <- s2_cohort()
  separated <- c(stats::runif(40, 0, 0.4), stats::runif(40, 0.6, 1))
  outcome <- rep(0:1, each = 40)
  row <- suppressWarnings(
    mysterymodel:::mm_metrics(separated, outcome, basis = "probe"))
  expect_equal(row$c_upper - row$c_lower, 0)
  expect_match(row$note, "zero width")
  expect_match(row$note, "not a statement of precision")
})

test_that("saboteur: non-events taken on trust rather than counted", {
  # Reported as n minus events, so a forged column cannot disagree with the
  # rows that were scored.
  cohort <- s2_cohort()
  project <- s2_project(cohort, split_var = "year", split_at = 2023)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- suppressWarnings(mm_validate(model, cohort, B = 10))
  expect_equal(v$metrics$non_events, v$metrics$n - v$metrics$events)
  held <- v$metrics[v$metrics$basis == "held out", ]
  outside <- cohort[cohort$year >= 2023, , drop = FALSE]
  expect_equal(held$non_events, sum(outside$event == 0))
})

test_that("saboteur: a corrected c-statistic handed an apparent interval", {
  # The two bootstrap rows must never carry one. A reader comparing down the
  # column would otherwise take the apparent row's interval as theirs.
  cohort <- s2_cohort()
  project <- s2_project(cohort, split_var = "year", split_at = 2023)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- suppressWarnings(mm_validate(model, cohort, B = 10,
                                    full_process = TRUE))
  corrected <- v$metrics[grepl("^bootstrap", v$metrics$basis), ]
  expect_equal(nrow(corrected), 2L)
  expect_true(all(is.na(corrected$c_lower)))
  expect_true(all(is.na(corrected$c_upper)))
  expect_true(all(grepl("No interval", corrected$note)))
  apparent <- v$metrics[v$metrics$basis == "apparent", ]
  expect_false(is.na(apparent$c_lower))
})
