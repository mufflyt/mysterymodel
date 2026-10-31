# The comparison category a categorical predictor is measured against, and
# the two kinds of data this package cannot model.

bl_cohort <- function(n = 600, prevalence = 0.15, seed = 1978) {
  mm_synthetic_cohort(n = n, prevalence = prevalence, seed = seed)
}

test_that("a declared baseline reparameterises the report, not the model", {
  # Which level is first decides what every other coefficient for that
  # predictor is measured against. It must not decide anything else.
  cohort <- bl_cohort()
  predictors <- c("age", "sex", "indication")
  plain <- mm_project("uds", "event", predictors, positive_class = 1,
                      cohort = cohort, seed = 1978)
  declared <- mm_project("uds", "event", predictors, positive_class = 1,
                         cohort = cohort, seed = 1978,
                         reference = list(sex = "male",
                                          indication = "retention"))
  a <- suppressWarnings(mm_model(plain, cohort))
  b <- suppressWarnings(mm_model(declared, cohort))

  # Alphabetical by default, declared when declared.
  expect_true("sex=male" %in% names(stats::coef(a$fit)))
  expect_true("sex=female" %in% names(stats::coef(b$fit)))
  expect_false("indication=retention" %in% names(stats::coef(b$fit)))

  # Same model: every prediction, and the apparent discrimination.
  expect_equal(mm_predict(a, cohort)$.pred, mm_predict(b, cohort)$.pred)
  expect_equal(unname(a$fit$stats["C"]), unname(b$fit$stats["C"]))
  expect_equal(unname(a$fit$deviance[2]), unname(b$fit$deviance[2]))

  # The datadist and the schema agree with the fit about which level leads,
  # because a nomogram axis and a refused level both read them.
  expect_identical(b$schema$predictors$indication$levels[1], "retention")
  expect_identical(as.character(b$datadist$values$indication[1]),
                   "retention")
  expect_identical(b$reference, list(sex = "male",
                                     indication = "retention"))
})

test_that("a plan that cannot be meant fails when the baseline is written", {
  cohort <- bl_cohort()
  expect_error(mm_project("uds", "event", c("age", "sex"), cohort = cohort,
                          reference = list(age = 50)),
               "continuous predictor")
  expect_error(mm_project("uds", "event", c("age", "sex"), cohort = cohort,
                          reference = list(sex = "other")),
               "not an observed value")
  expect_error(mm_project("uds", "event", c("age", "sex"), cohort = cohort,
                          reference = list(bmi = "x")),
               "does not declare")
  expect_error(mm_project("uds", "event", c("age", "sex"), cohort = cohort,
                          reference = list("male")),
               "must be a named list")
  expect_error(mm_project("uds", "event", c("age", "sex"), cohort = cohort,
                          reference = list(sex = c("male", "female"))),
               "a single level name")
})

test_that("a declared baseline is refused rather than replaced when it goes", {
  # The point of declaring it. Replacing it silently would measure every
  # coefficient against a level nobody chose, under the same names.
  cohort <- bl_cohort()
  cohort$indication <- as.character(cohort$indication)
  cohort$indication[1:9] <- "rare"
  cohort$indication <- factor(cohort$indication)
  cohort$age[cohort$indication == "rare"] <- NA

  project <- mm_project("uds", "event", c("age", "sex", "indication"),
                        positive_class = 1, cohort = cohort, seed = 1978,
                        reference = list(indication = "rare"))
  expect_error(suppressWarnings(mm_model(project, cohort)),
               "no row that survived eligibility carries it")
  expect_error(suppressWarnings(mm_model(project, cohort)),
               "refused rather than replaced")

  # Declaring a surviving level works on the same cohort.
  fine <- mm_project("uds", "event", c("age", "sex", "indication"),
                     positive_class = 1, cohort = cohort, seed = 1978,
                     reference = list(indication = "prolapse"))
  fitted <- suppressWarnings(mm_model(fine, cohort))
  expect_identical(fitted$schema$predictors$indication$levels[1],
                   "prolapse")
})

test_that("overriding the declared baseline records a departure", {
  cohort <- bl_cohort()
  declared <- mm_project("uds", "event", c("age", "sex", "indication"),
                         positive_class = 1, cohort = cohort, seed = 1978,
                         reference = list(sex = "male"))
  said <- character(0)
  over <- withCallingHandlers(
    mm_model(declared, cohort, reference = list(sex = "female")),
    warning = function(w) {
      said <<- c(said, conditionMessage(w)); invokeRestart("muffleWarning")
    })
  expect_length(over$departures, 1L)
  expect_match(over$departures, "reference")
  expect_match(over$departures, "sex=male")
  expect_match(over$departures, "sex=female")
  expect_true(any(grepl("departs from the project", said)))

  # Following the plan is not a departure.
  expect_length(suppressWarnings(mm_model(declared, cohort))$departures, 0L)
  # Nor is declaring nothing and passing nothing.
  bare <- mm_project("uds", "event", c("age", "sex"), positive_class = 1,
                     cohort = cohort, seed = 1978)
  expect_length(suppressWarnings(
    mm_model(bare, cohort, reference = list(sex = "male")))$departures, 0L)
})

test_that("an undeclared baseline that moves is reported", {
  # Found by asking whether cleaning ordered its factors. A factor's first
  # level is the baseline, droplevels() can remove it, and the coefficient
  # names do not change: the same term then means something different.
  cohort <- bl_cohort()
  cohort$indication <- as.character(cohort$indication)
  cohort$indication[1:12] <- "aaa_first"
  cohort$indication <- factor(cohort$indication)
  project <- mm_project("uds", "event", c("age", "bmi", "indication"),
                        positive_class = 1, cohort = cohort, seed = 1978)
  intact <- suppressWarnings(mm_model(project, cohort))
  expect_length(intact$reference_moved, 0L)

  holey <- cohort
  holey$bmi[holey$indication == "aaa_first"] <- NA
  said <- character(0)
  moved <- withCallingHandlers(mm_model(project, holey),
    warning = function(w) {
      said <<- c(said, conditionMessage(w)); invokeRestart("muffleWarning")
    })
  expect_equal(moved$reference_moved$indication,
               c(from = "aaa_first", to = "incontinence"))
  expect_true(any(grepl("comparison category moved", said)))
  expect_match(paste(capture.output(print(moved)), collapse = " "),
               "BASELINE")

  # The same coefficient name, against two different baselines.
  shared <- intersect(names(stats::coef(intact$fit)),
                      names(stats::coef(moved$fit)))
  shared <- grep("indication", shared, value = TRUE)
  expect_gt(length(shared), 0L)
  expect_false(isTRUE(all.equal(stats::coef(intact$fit)[shared],
                                stats::coef(moved$fit)[shared])))

  # Declaring the baseline is what prevents it, and here it cannot be met.
  pinned <- mm_project("uds", "event", c("age", "bmi", "indication"),
                       positive_class = 1, cohort = cohort, seed = 1978,
                       reference = list(indication = "aaa_first"))
  expect_error(suppressWarnings(mm_model(pinned, holey)),
               "refused rather than replaced")
})

test_that("a tabulation is refused as an outcome, with the reason", {
  # Found on datasets::esoph. mm_project accepted a column of event counts,
  # and mm_model then advised setting positive_class, which would have fitted
  # a model of exactly that many events per group.
  e <- datasets::esoph
  expect_error(mm_project("esoph", "ncases", c("agegp", "alcgp", "tobgp"),
                          cohort = e),
               "models a binary outcome")
  expect_error(mm_project("esoph", "ncases", c("agegp", "alcgp", "tobgp"),
                          cohort = e),
               "tabulation and not a patient-level outcome")

  # A two-valued outcome is unaffected, and so is one with a named event.
  cohort <- bl_cohort()
  expect_no_error(mm_project("uds", "event", c("age", "sex"),
                             positive_class = 1, cohort = cohort))
  three <- cohort
  three$grade <- factor(sample(c("a", "b", "c"), nrow(three), TRUE))
  expect_error(mm_project("uds", "grade", c("age", "sex"), cohort = three),
               "models a binary outcome")
  expect_no_error(mm_project("uds", "grade", c("age", "sex"), cohort = three,
                             positive_class = "a"))
})

test_that("an ordered factor is refused with both routes that work", {
  # rms::lrm() answers one from inside Design() with advice to change a
  # global contrast option, which is not a decision this package makes for
  # anyone, and rms's own documentation warns against relying on it.
  cohort <- bl_cohort()
  cohort$band <- factor(cut(cohort$age, 3), ordered = TRUE)
  expect_error(mm_project("uds", "event", c("band", "sex"),
                          positive_class = 1, cohort = cohort),
               "ordered factor")
  expect_error(mm_project("uds", "event", c("band", "sex"),
                          positive_class = 1, cohort = cohort),
               "factor\\(x, ordered = FALSE\\)")

  # Checked at fit time too, because a project may be written without a
  # cohort to check it against.
  blind <- mm_project("uds", "event", c("band", "sex"), positive_class = 1,
                      seed = 1978)
  expect_error(suppressWarnings(mm_model(blind, cohort)), "ordered factor")

  # Both documented routes work.
  unordered <- cohort
  unordered$band <- factor(as.character(unordered$band))
  expect_no_error(suppressWarnings(
    mm_model(mm_project("uds", "event", c("band", "sex"),
                        positive_class = 1, cohort = unordered,
                        seed = 1978), unordered)))
  scored <- cohort
  scored$band <- as.numeric(scored$band)
  expect_no_error(suppressWarnings(
    mm_model(mm_project("uds", "event", c("band", "sex"),
                        positive_class = 1, cohort = scored, seed = 1978),
             scored)))
})
