# The fixed-model bootstrap row has to be as honest as the full-process row
# beside it: drawn on the same unit the project declares, computed on the rows
# the model was fitted on, and explicit about how many resamples fitted.

boot_cohort <- function(n = 300, seed = 1978) {
  mm_synthetic_cohort(n = n, prevalence = 0.13, seed = seed)
}

boot_project <- function(cohort, cluster = NULL) {
  mm_project("uds", "event", c("age", "bmi", "sex", "prior_uti"),
             positive_class = 1, cohort = cohort, cluster_id = cluster,
             seed = 1978)
}

test_that("the fixed-model bootstrap draws the unit the project declares", {
  cohort <- boot_cohort()
  clustered <- suppressWarnings(
    mm_model(boot_project(cohort, "pid"), cohort, nonlinear = "age"))
  v <- mm_validate(clustered, cohort, B = 100)
  boot <- v$metrics[v$metrics$basis == "bootstrap, fixed model", ]

  expect_match(boot$note, "Resampled by whole pid")
  expect_equal(v$fixed_model$clustered_by, "pid")

  # Against rms called directly, both ways, so the test fails if the cluster
  # argument is dropped and fails if it is passed when it should not be.
  old <- options(datadist = clustered$datadist)
  on.exit(options(old), add = TRUE)
  set.seed(1978)
  with_cluster <- rms::validate(clustered$fit, B = 100,
                                cluster = as.character(cohort$pid))
  set.seed(1978)
  without <- rms::validate(clustered$fit, B = 100)

  expect_equal(boot$c_stat, 0.5 + with_cluster["Dxy", "index.corrected"] / 2)
  expect_equal(boot$cal_slope,
               unname(with_cluster["Slope", "index.corrected"]))

  # And the argument demonstrably changes the answer, so the assertion above
  # is not satisfied by rms quietly ignoring it.
  expect_false(isTRUE(all.equal(
    unname(with_cluster["Dxy", "index.corrected"]),
    unname(without["Dxy", "index.corrected"]))))
})

test_that("without a declared cluster it still draws rows, and says so", {
  cohort <- boot_cohort()
  plain <- suppressWarnings(
    mm_model(boot_project(cohort), cohort, nonlinear = "age"))
  v <- mm_validate(plain, cohort, B = 100)
  boot <- v$metrics[v$metrics$basis == "bootstrap, fixed model", ]

  expect_match(boot$note, "Resampled by row")
  expect_null(v$fixed_model$clustered_by)

  old <- options(datadist = plain$datadist)
  on.exit(options(old), add = TRUE)
  set.seed(1978)
  direct <- rms::validate(plain$fit, B = 100)
  expect_equal(boot$c_stat, 0.5 + direct["Dxy", "index.corrected"] / 2)
})

test_that("a row with no cluster id leaves at fitting, with a reason", {
  # It cannot take part in clustered resampling, and a bootstrap over a subset
  # of the fitted rows corrects the optimism of a different model from the one
  # reported. So the cluster column is required of a development frame and the
  # exclusion is attributed, rather than surfacing later as a failure inside
  # predab.resample(), whose split() would have discarded it without a word.
  cohort <- boot_cohort()
  cohort$pid[c(1, 2, 3)] <- NA

  said <- character(0)
  model <- withCallingHandlers(
    mm_model(boot_project(cohort, "pid"), cohort, nonlinear = "age"),
    warning = function(cond) {
      said <<- c(said, conditionMessage(cond))
      invokeRestart("muffleWarning")
    })

  expect_equal(model$n_incomplete, 3L)
  expect_equal(unname(model$incomplete_by[["pid"]]), 3L)
  expect_equal(model$n_dev, nrow(cohort) - 3L)
  expect_true(any(grepl("declares a cluster", said)))

  # And validation then runs on that cohort, reporting the fitted sample.
  v <- mm_validate(model, cohort, B = 10)
  expect_equal(v$metrics$n[v$metrics$basis == "apparent"], model$n_dev)
  expect_match(v$metrics$note[v$metrics$basis == "bootstrap, fixed model"],
               "Resampled by whole pid")

  # Held-out rows are scored once and never resampled, so an identifier they
  # lack costs them nothing.
  e <- mm_evaluable(boot_project(cohort, "pid"), cohort,
                    require_cluster = FALSE)
  expect_equal(e$n_scored, nrow(cohort))
})

test_that("the resamples rms actually fitted are reported, not the request", {
  cohort <- boot_cohort()
  model <- suppressWarnings(
    mm_model(boot_project(cohort), cohort, nonlinear = "age"))
  v <- mm_validate(model, cohort, B = 50)

  expect_equal(v$fixed_model$B, 50L)
  expect_match(v$metrics$note[v$metrics$basis == "bootstrap, fixed model"],
               "50 of 50 resample\\(s\\) fitted")
  expect_true(v$fixed_model$adequate)
})

test_that("resamples rms could not fit are disclosed on every surface", {
  # A category carried by one row is absent from about a third of resamples,
  # each of which rms drops. It keeps btrain[1:j, ] and reports the shortfall
  # only behind `pr`, which validate.lrm defaults off, so without reading the
  # `n` column the corrected index is an average over a self-selected subset.
  cohort <- mm_synthetic_cohort(n = 150, prevalence = 0.12, seed = 17)
  cohort$indication <- as.character(cohort$indication)
  cohort$indication[1] <- "singleton"
  cohort$indication <- factor(cohort$indication)
  project <- mm_project("uds", "event",
                        c("age", "bmi", "sex", "indication"),
                        positive_class = 1, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  said <- character(0)
  v <- withCallingHandlers(
    mm_validate(model, cohort, B = 100),
    warning = function(cond) {
      said <<- c(said, conditionMessage(cond))
      invokeRestart("muffleWarning")
    })

  expect_lt(v$fixed_model$fitted, 100L)
  expect_lt(v$fixed_model$fitted, ceiling(0.8 * 100))
  expect_false(v$fixed_model$adequate)
  expect_true(any(grepl("rms fitted only", said)))

  note <- v$metrics$note[v$metrics$basis == "bootstrap, fixed model"]
  expect_match(note, paste0(v$fixed_model$fitted, " of 100"))
  expect_match(note, "INADEQUATE")
  expect_match(paste(capture.output(print(v)), collapse = " "),
               "INADEQUATE: rms fitted")
})

test_that("validation refuses a different cohort of the same size", {
  cohort <- boot_cohort()
  model <- suppressWarnings(
    mm_model(boot_project(cohort), cohort, nonlinear = "age"))

  # Same number of evaluable rows, different data. A count cannot tell these
  # apart, and the apparent basis is defined as the rows that were fitted.
  altered <- cohort
  altered$age <- rev(altered$age)
  expect_equal(nrow(altered), nrow(cohort))
  expect_error(mm_validate(model, altered, B = 5), "not the same rows")
  expect_error(mm_validate(model, altered, B = 5), "never saw")

  # The full-process bootstrap goes through the same check.
  expect_error(
    mysterymodel:::mm_full_process(model, altered, B = 5),
    "not the same rows")

  # A reordering is refused too, and the message says what to do about it.
  shuffled <- cohort[rev(seq_len(nrow(cohort))), , drop = FALSE]
  expect_error(mm_validate(model, shuffled, B = 5),
               "order it was fitted in")

  expect_silent(mm_validate(model, cohort, B = 5))
})

test_that("the identity check survives a level the fit dropped", {
  # mm_model() droplevels a category carried only by excluded rows, so the
  # frame it fitted has a smaller level set than the one a caller re-derives.
  # Hashing values rather than level sets is what keeps that from reading as
  # a different cohort.
  cohort <- mm_synthetic_cohort(n = 300, seed = 1978)
  cohort$indication <- as.character(cohort$indication)
  cohort$indication[1:5] <- "urgency"
  cohort$indication <- factor(cohort$indication)
  cohort$bmi[1:5] <- NA
  project <- mm_project("uds", "event",
                        c("age", "bmi", "sex", "indication"),
                        positive_class = 1, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  expect_equal(model$lost_levels, list(indication = "urgency"))
  expect_silent(suppressWarnings(mm_validate(model, cohort, B = 5)))
})
