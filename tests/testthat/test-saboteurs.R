# Saboteurs. Each one breaks something on purpose and asserts that the
# safeguard notices. A guard nobody has tried to defeat is a comment.
#
# These differ from the rest of the suite in what they are for: not that a
# function works on good input, but that a specific wrong thing cannot pass
# quietly. Where the sabotage is subtle, the comment says what a reader of the
# output would have believed if the guard were absent.

sab_cohort <- function(n = 400, seed = 1978) {
  mm_synthetic_cohort(n = n, prevalence = 0.13, seed = seed)
}
sab_project <- function(cohort) {
  mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
             positive_class = 1, cohort = cohort, split_var = "year",
             split_at = 2023, cluster_id = "pid", seed = 1978)
}
sab_model <- function(cohort) {
  suppressWarnings(mm_model(sab_project(cohort), cohort, nonlinear = "age",
                            interactions = list(c("prior_uti", "sex"))))
}

# ---- the nomogram, which is the published instrument ------------------------

test_that("saboteur: points added to one nomogram axis are detected", {
  # A nomogram is read by hand years after the code stopped running, so the
  # only moment anyone can notice a wrong axis is while it is drawn.
  cohort <- sab_cohort(); model <- sab_model(cohort)
  nom <- mm_nomogram(model, out_dir = NULL)

  tampered <- nom$nomogram
  axis <- mysterymodel:::mm_axis_names(tampered)[1]
  tampered[[axis]]$points <- tampered[[axis]]$points + 7

  profile <- mysterymodel:::mm_tick_profiles(
    nom$nomogram, model)[1, , drop = FALSE]
  gap <- abs(mysterymodel:::mm_nomogram_risk(tampered, profile) -
               mm_predict(model, profile)$.pred)

  expect_gt(gap, nom$tolerance)
  expect_lt(nom$worst_disagreement, nom$tolerance)
})

test_that("saboteur: a linear predictor axis that is not affine is refused", {
  # The points-to-risk reader uses the exact line through that axis. If the
  # axis were not a line, the line would be a wrong answer that looks right.
  cohort <- sab_cohort(); model <- sab_model(cohort)
  nom <- mm_nomogram(model, out_dir = NULL)

  bent <- nom$nomogram
  bent$lp$x.real[2] <- bent$lp$x.real[2] + 0.4
  expect_error(mysterymodel:::mm_total_to_lp(bent, 50), "not affine")
  expect_false(is.na(mysterymodel:::mm_total_to_lp(nom$nomogram, 50)))
})

test_that("saboteur: a coefficient changed after drawing is detected", {
  # The drawn nomogram and the fit are then two different models, and the
  # agreement check is the only thing that can say so.
  cohort <- sab_cohort(); model <- sab_model(cohort)
  nom <- mm_nomogram(model, out_dir = NULL)

  drifted <- model
  drifted$fit$coefficients[2] <- drifted$fit$coefficients[2] * 1.5
  profile <- mysterymodel:::mm_tick_profiles(
    nom$nomogram, model)[2, , drop = FALSE]
  gap <- abs(mysterymodel:::mm_nomogram_risk(nom$nomogram, profile) -
               mm_predict(drifted, profile)$.pred)
  expect_gt(gap, nom$tolerance)
})

# ---- the prediction schema, which is what a deployed model may receive ------

test_that("saboteur: a narrowed schema range makes a value extrapolation", {
  # Extrapolation is decided by the range recorded at fit time, not guessed
  # from the value. Narrowing the record is how to prove which.
  cohort <- sab_cohort(); model <- sab_model(cohort)
  inside <- cohort[which.max(cohort$age), , drop = FALSE]
  expect_false(mm_predict(model, inside)$.extrapolated)

  narrowed <- model
  narrowed$schema$predictors$age$range <- c(40, 50)
  expect_true(mm_predict(narrowed, inside)$.extrapolated)
})

test_that("saboteur: a schema that forgets a real level refuses that level", {
  # The schema is authoritative over the fit, deliberately: a level the schema
  # does not list must not be scored even when the fit could score it.
  cohort <- sab_cohort(); model <- sab_model(cohort)
  male <- cohort[cohort$sex == "male", ][1, , drop = FALSE]
  expect_false(is.na(mm_predict(model, male)$.pred))

  forgetful <- model
  forgetful$schema$predictors$sex$levels <- "female"
  expect_error(mm_predict(forgetful, male), "never saw: male")
})

test_that("saboteur: a bare rms fit is not an mm_model", {
  cohort <- sab_cohort(); model <- sab_model(cohort)
  expect_error(mm_predict(model$fit, cohort[1, ]), "must come from mm_model")
})

test_that("saboteur: a predictor column removed from newdata is named", {
  cohort <- sab_cohort(); model <- sab_model(cohort)
  expect_error(
    mm_predict(model, cohort[1, setdiff(names(cohort), "bmi")]),
    "missing required predictor\\(s\\): bmi")
})

test_that("saboteur: a level the fit never saw is refused by name", {
  cohort <- sab_cohort(); model <- sab_model(cohort)
  invented <- cohort[1, ]
  invented$prior_uti <- factor("maybe", levels = c("no", "yes", "maybe"))
  expect_error(mm_predict(model, invented), "never saw: maybe")
})

# ---- the cohort a model is judged against ----------------------------------

test_that("saboteur: two outcomes swapped is a different cohort", {
  # The marginals are untouched: same rows, same number of events, same
  # prevalence. Only the pairing moved, which is the thing a c-statistic
  # measures, so a count-based check would pass this.
  cohort <- sab_cohort(); model <- sab_model(cohort)
  swapped <- cohort
  i <- which(swapped$event == 1L)[1]; j <- which(swapped$event == 0L)[1]
  swapped$event[i] <- 0L; swapped$event[j] <- 1L

  expect_equal(sum(swapped$event), sum(cohort$event))
  expect_equal(nrow(swapped), nrow(cohort))
  expect_error(mm_validate(model, swapped, B = 5), "not the same rows")
})

test_that("saboteur: a reordered cohort is refused, and told why", {
  cohort <- sab_cohort(); model <- sab_model(cohort)
  reversed <- cohort[rev(seq_len(nrow(cohort))), , drop = FALSE]
  expect_error(mm_validate(model, reversed, B = 5), "not the same rows")
  expect_error(mm_validate(model, reversed, B = 5), "order it was fitted in")
})

test_that("saboteur: patient ids reshuffled is a different cohort", {
  # Same identifiers, same number of visits each, attached to different rows.
  # Every clustered resample would then draw the wrong groups.
  cohort <- sab_cohort(); model <- sab_model(cohort)
  reassigned <- cohort
  set.seed(9)
  reassigned$pid <- sample(reassigned$pid)
  expect_setequal(table(reassigned$pid), table(cohort$pid))
  expect_error(mm_validate(model, reassigned, B = 5), "not the same rows")
})

test_that("saboteur: blanked held-out outcomes are excluded, not scored as 0", {
  # Counting a missing outcome as a non-event leaves the event count alone
  # while inflating the denominator, so every reported risk comes out low and
  # nothing in the table looks wrong.
  cohort <- sab_cohort()
  held <- which(cohort$year >= 2023)
  blanked <- cohort
  blanked$event[held[1:10]] <- NA

  model <- sab_model(blanked)
  v <- suppressWarnings(mm_validate(model, blanked, B = 5))
  row <- v$metrics[v$metrics$basis == "held out", ]

  expect_equal(row$n, sum(!is.na(blanked$event[held])))
  expect_equal(row$events, sum(blanked$event[held] == 1L, na.rm = TRUE))
  expect_equal(v$eligibility$held_out$missing_outcome, 10L)
  expect_lt(row$n, length(held))

  # The count reported as scored must be the count actually scored. Without
  # this, mm_metrics() dropping NA outcomes of its own accord is enough to
  # make the numbers above right while the eligibility report is wrong, so the
  # saboteur would pass against an eligibility rule that ignored the outcome.
  expect_equal(row$n, v$eligibility$held_out$n_scored)
})

test_that("saboteur: blanked cluster ids leave at fitting, attributed", {
  cohort <- sab_cohort()
  blanked <- cohort
  blanked$pid[1:3] <- NA
  lost <- sum(blanked$year[1:3] < 2023)   # only development rows can be lost
  expect_gt(lost, 0)

  model <- sab_model(blanked)
  expect_equal(model$n_incomplete, lost)
  expect_equal(unname(model$incomplete_by[["pid"]]), lost)
})

# ---- the plan, before anything is fitted -----------------------------------

test_that("saboteur: the outcome among the predictors is refused", {
  expect_error(mm_project("uds", "event", c("age", "event")),
               "also in `predictors`")
})

test_that("saboteur: a plausible but unobserved positive class is refused", {
  # "1" as text reads correctly and is not a value of the column. An inverted
  # or absent positive class inverts every risk the model goes on to report.
  cohort <- sab_cohort()
  expect_error(
    mm_project("uds", "event", c("age", "bmi"), positive_class = "yes",
               cohort = cohort),
    "is not an observed value")
})

test_that("saboteur: a missing split variable is refused, not dropped", {
  cohort <- sab_cohort()
  gap <- cohort
  gap$year[5] <- NA
  project <- mm_project("uds", "event", c("age", "bmi"), positive_class = 1,
                        split_var = "year", split_at = 2023, seed = 1978)
  expect_error(suppressWarnings(mm_model(project, gap)),
               "fall on neither side of the split")
})

test_that("saboteur: an outcome that varies only in dropped rows is refused", {
  # It varies in the cohort and does not vary in the rows that can be fitted,
  # which is the case a check on the supplied frame would miss.
  cohort <- sab_cohort()
  hidden <- cohort
  hidden$event <- 0L
  hidden$event[1:4] <- 1L
  hidden$bmi[1:4] <- NA

  project <- mm_project("uds", "event", c("age", "bmi"), positive_class = 1,
                        seed = 1978)
  expect_error(suppressWarnings(mm_model(project, hidden)),
               "does not vary among the")
})

test_that("saboteur: an interaction without its main effect is refused", {
  cohort <- sab_cohort()
  thin <- mm_project("uds", "event", c("age", "sex"), positive_class = 1,
                     seed = 1978)
  expect_error(
    suppressWarnings(mm_model(thin, cohort,
                              interactions = list(c("sex", "prior_uti")))),
    "needs its main effect")
})

# ---- the eligibility ledger -------------------------------------------------

test_that("saboteur: a rule giving the wrong number of answers is refused", {
  cohort <- sab_cohort()
  expect_error(mm_clean(cohort, list("short" = ~ c(TRUE, FALSE))),
               "must give one TRUE or FALSE per row")
})

test_that("saboteur: a rule that is not a one-sided formula is refused", {
  # A bare expression would be evaluated before the cohort is in scope, and a
  # two-sided one is not the thing the ledger labels.
  cohort <- sab_cohort()
  expect_error(mm_clean(cohort, list("bare" = quote(age > 40))),
               "are not formulas")
  expect_error(mm_clean(cohort, list("two sided" = keep ~ age > 40)),
               "have a left-hand side")
  expect_error(mm_clean(cohort, list(~ age > 40)), "every rule needs a name")
})
