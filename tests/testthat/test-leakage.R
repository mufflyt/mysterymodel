# Outcome leakage. A predictor carrying the outcome is not predicting it, and
# the model it produces reports near-perfect discrimination, which reads as
# success. The by-name check that `outcome` is not among `predictors` cannot
# see a renamed copy, which is what these cover.
#
# The tiers are not interchangeable. Duplication is settled by arithmetic and
# blocks. Separation can be a small cohort and only warns.

leak_cohort <- function(n = 200L, seed = 42L) {
  set.seed(seed)
  cohort <- data.frame(outcome = rep(c(0L, 1L), each = n / 2L),
                       age = stats::rnorm(n, 55, 10))
  cohort$copy_integer <- cohort$outcome
  cohort$copy_logical <- cohort$outcome == 1L
  cohort$copy_factor <- factor(ifelse(cohort$outcome == 1L, "bad", "good"))
  cohort$copy_character <- ifelse(cohort$outcome == 1L, "event", "none")
  cohort$complement <- 1L - cohort$outcome
  cohort$honest <- cohort$outcome * 2 + stats::rnorm(n, 0, 1.4)
  cohort
}

leak_fit <- function(cohort, predictors) {
  project <- mm_project("leak", "outcome", predictors, positive_class = 1,
                        cohort = cohort, seed = 1978)
  suppressWarnings(mm_model(project, cohort))
}

# ---- tier 1, duplication, which blocks ------------------------------------

test_that("a renamed exact copy of the outcome is refused", {
  cohort <- leak_cohort()
  expect_error(leak_fit(cohort, c("age", "copy_integer")),
               "outcome leakage")
  expect_error(leak_fit(cohort, c("age", "copy_integer")),
               "reproduces the outcome on every one of the 200")
  expect_error(leak_fit(cohort, c("age", "copy_integer")),
               "Remove it before fitting")
})

test_that("a logical copy of a 0/1 outcome is refused", {
  cohort <- leak_cohort()
  expect_error(leak_fit(cohort, c("age", "copy_logical")),
               "TRUE is the event")
})

test_that("a factor copy is refused, and the mapping is named", {
  # The labels carry no information, so the check tries both assignments
  # rather than trusting that "bad" means the event.
  cohort <- leak_cohort()
  expect_error(leak_fit(cohort, c("age", "copy_factor")),
               "\\\"bad\\\" is the event")
})

test_that("a character copy is refused", {
  cohort <- leak_cohort()
  expect_error(leak_fit(cohort, c("age", "copy_character")),
               "outcome leakage")
})

test_that("the exact complement of the outcome is refused", {
  cohort <- leak_cohort()
  expect_error(leak_fit(cohort, c("age", "complement")),
               "exact complement")
})

test_that("the outcome under its own name is still refused earlier", {
  cohort <- leak_cohort()
  expect_error(
    mm_project("leak", "outcome", c("age", "outcome")),
    "also in `predictors`")
})

test_that("without the guard this is what the model would report", {
  # The reason duplication blocks rather than warns: the number it produces is
  # not implausible enough to catch anyone's eye.
  cohort <- leak_cohort()
  project <- mm_project("leak", "outcome", c("age", "copy_integer"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  unguarded <- suppressWarnings(
    mm_model(project, cohort, check_leakage = FALSE))
  v <- mm_validate(unguarded, cohort, B = 10)
  expect_equal(v$metrics$c_stat[v$metrics$basis == "apparent"], 1)
  expect_error(suppressWarnings(mm_model(project, cohort)), "outcome leakage")
})

# ---- tier 2 and 3, separation, which warns --------------------------------

test_that("a multi-level categorical that separates warns, and fits", {
  set.seed(7)
  cohort <- data.frame(outcome = rep(c(0L, 1L), each = 60L),
                       age = stats::rnorm(120, 55, 10))
  cohort$stage <- factor(ifelse(cohort$outcome == 1L,
                                sample(c("III", "IV"), 120, TRUE), "I"))
  project <- mm_project("leak", "outcome", c("age", "stage"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  expect_warning(model <- mm_model(project, cohort),
                 "every observed level falls in one outcome class")
  expect_s3_class(model, "mm_model")
  flagged <- suppressWarnings(mm_model(project, cohort))$leakage
  expect_equal(vapply(flagged, function(f) f$tier, integer(1)), 2L)
})

test_that("a numeric predictor separated by a threshold warns, and fits", {
  set.seed(7)
  cohort <- data.frame(outcome = rep(c(0L, 1L), each = 60L),
                       age = stats::rnorm(120, 55, 10))
  cohort$marker <- ifelse(cohort$outcome == 1L,
                          stats::runif(120, 10, 20), stats::runif(120, 0, 5))
  project <- mm_project("leak", "outcome", c("age", "marker"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  expect_warning(model <- mm_model(project, cohort),
                 "every event lies above every non-event")
  expect_s3_class(model, "mm_model")
})

test_that("a rare outcome with an accidental perfect predictor is not blocked", {
  # Four events and a marker that happens to separate them. This is exactly
  # the case a hard stop on perfect separation would destroy.
  set.seed(3)
  cohort <- data.frame(outcome = c(rep(0L, 96), rep(1L, 4)),
                       age = stats::rnorm(100, 55, 10))
  cohort$marker <- c(stats::runif(96, 0, 1), stats::runif(4, 5, 6))
  project <- mm_project("leak", "outcome", c("age", "marker"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  expect_warning(model <- mm_model(project, cohort), "possible outcome leakage")
  expect_s3_class(model, "mm_model")
})

test_that("a strong but non-deterministic predictor says nothing", {
  cohort <- leak_cohort()
  expect_silent(suppressWarnings(leak_fit(cohort, c("age", "honest"))))
  model <- leak_fit(cohort, c("age", "honest"))
  expect_length(model$leakage, 0L)
  # And it really is strongly associated, so this is not a weak-signal pass.
  expect_gt(abs(stats::cor(cohort$honest, cohort$outcome)), 0.5)
})

# ---- the frame the scan runs on --------------------------------------------

test_that("the scan reads the development rows, not the held-out ones", {
  # A copy that exists only after the split must not block a development
  # model, and must not be reached by looking at held-out outcomes.
  set.seed(11)
  cohort <- data.frame(
    outcome = rep(c(0L, 1L), each = 100L),
    age = stats::rnorm(200, 55, 10),
    year = rep(c(2021L, 2024L), length.out = 200L))
  cohort$shadow <- ifelse(cohort$year >= 2023, cohort$outcome,
                          sample(c(0L, 1L), 200, TRUE))
  project <- mm_project("leak", "outcome", c("age", "shadow"),
                        positive_class = 1, cohort = cohort,
                        split_var = "year", split_at = 2023, seed = 1978)
  expect_s3_class(suppressWarnings(mm_model(project, cohort)), "mm_model")

  # Reversed: a copy in the development rows only is refused.
  flipped <- cohort
  flipped$shadow <- ifelse(flipped$year < 2023, flipped$outcome,
                           sample(c(0L, 1L), 200, TRUE))
  expect_error(suppressWarnings(mm_model(project, flipped)),
               "outcome leakage")
})

test_that("an unused factor level does not hide a separating predictor", {
  # The scan reads observed values. Reading declared levels instead would let
  # an unused level, contributing no rows, break the all-levels-pure test and
  # suppress the finding.
  set.seed(5)
  cohort <- data.frame(outcome = rep(c(0L, 1L), each = 60L),
                       age = stats::rnorm(120, 55, 10))
  cohort$stage <- factor(ifelse(cohort$outcome == 1L, "IV", "I"),
                         levels = c("I", "II", "III", "IV"))
  expect_true("II" %in% levels(cohort$stage))
  expect_false("II" %in% as.character(cohort$stage))

  # Two observed levels that align exactly are duplication, not separation.
  expect_error(suppressWarnings(leak_fit(cohort, c("age", "stage"))),
               "outcome leakage")
})

test_that("missing values are compared pairwise and counted", {
  cohort <- leak_cohort()
  holey <- cohort
  holey$copy_integer[1:20] <- NA
  project <- mm_project("leak", "outcome", c("age", "copy_integer"),
                        positive_class = 1, seed = 1978)
  found <- mm_leakage(project, holey)
  expect_length(found, 1L)
  expect_equal(found[[1]]$tier, 1L)
  expect_equal(found[[1]]$n_compared, 180L)
  expect_equal(found[[1]]$n_missing, 20L)
})

test_that("a missing outcome is excluded from the comparison", {
  cohort <- leak_cohort()
  holey <- cohort
  holey$outcome[1:30] <- NA
  project <- mm_project("leak", "outcome", c("age", "copy_integer"),
                        positive_class = 1, seed = 1978)
  found <- mm_leakage(project, holey)
  expect_equal(found[[1]]$n_compared, 170L)
  expect_equal(found[[1]]$n_missing, 30L)
})

test_that("too little overlap is reported, not called duplication", {
  # An exact match over a handful of rows does not separate a copy from a
  # coincidence, so it is raised for a human instead of blocking.
  cohort <- leak_cohort(n = 200L)
  thin <- cohort
  # Four of each outcome class kept, so the outcome varies among the compared
  # rows and the verdict turns on the overlap alone.
  thin$copy_integer[setdiff(seq_len(200), c(1:4, 101:104))] <- NA
  expect_equal(sum(!is.na(thin$copy_integer)), 8L)
  expect_length(unique(thin$outcome[!is.na(thin$copy_integer)]), 2L)

  project <- mm_project("leak", "outcome", c("age", "copy_integer"),
                        positive_class = 1, seed = 1978)
  found <- mm_leakage(project, thin)
  expect_equal(found[[1]]$tier, 2L)
  expect_equal(found[[1]]$kind, "too few to judge")
  expect_match(found[[1]]$detail, "fewer than the 10 needed")
})

test_that("no verdict at all when the outcome does not vary in the overlap", {
  # Nothing can be concluded from rows that are all one class, so the
  # predictor is left alone rather than cleared or condemned.
  cohort <- leak_cohort(n = 200L)
  one_class <- cohort
  one_class$copy_integer[9:200] <- NA
  expect_length(unique(one_class$outcome[!is.na(one_class$copy_integer)]), 1L)
  project <- mm_project("leak", "outcome", c("age", "copy_integer"),
                        positive_class = 1, seed = 1978)
  expect_length(mm_leakage(project, one_class), 0L)
})

test_that("a column that cannot be read as binary is never duplication", {
  # Three or more observed values are not a binary outcome under another name,
  # and no string is coerced into one.
  expect_length(mm_binary_forms(c("a", "b", "c")), 0L)
  expect_length(mm_binary_forms(c(1, 2, 3)), 0L)
  expect_length(mm_binary_forms(c(0, 1, 0, 1)), 1L)
  expect_length(mm_binary_forms(c(TRUE, FALSE)), 1L)
  expect_length(mm_binary_forms(factor(c("x", "y"))), 2L)
})

test_that("the full-process refit does not rescan each resample", {
  # The declared cohort is scanned once. A resample is a subset of it, so a
  # match inside one is a property of the draw, and erroring there would
  # silently cost valid resamples.
  cohort <- mm_synthetic_cohort(n = 300, prevalence = 0.13, seed = 1978)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  fp <- suppressWarnings(
    mysterymodel:::mm_full_process(model, cohort, B = 25))
  expect_equal(fp$valid, 25L)
})
