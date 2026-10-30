fp_fixture <- function(cluster = NULL, n = 500, seed = 1978) {
  cohort <- mm_synthetic_cohort(n = n, seed = seed)
  project <- mm_project("uds", "event",
                        c("age", "bmi", "sex", "prior_uti"),
                        cohort = cohort, split_var = "year",
                        split_at = 2023, cluster_id = cluster)
  list(cohort = cohort,
       model = suppressWarnings(
         mm_model(project, cohort, nonlinear = "age")))
}

test_that("full process adds its own basis and claims it", {
  f <- fp_fixture()
  v <- mm_validate(f$model, f$cohort, B = 15, full_process = TRUE)
  expect_true("bootstrap, full process" %in% v$metrics$basis)
  expect_true(v$full_process)
})

test_that("without it, the result does not claim to be a strategy", {
  f <- fp_fixture()
  v <- mm_validate(f$model, f$cohort, B = 15)
  expect_false("bootstrap, full process" %in% v$metrics$basis)
  expect_false(v$full_process)
})

test_that("every basis survives being added, in order", {
  # The rows were once assigned by fixed index, so adding the full-process
  # basis overwrote the held-out one. Nothing said so; the table was simply
  # one row short.
  f <- fp_fixture()
  v <- mm_validate(f$model, f$cohort, B = 15, full_process = TRUE)
  expect_equal(v$metrics$basis,
               c("apparent", "bootstrap, fixed model",
                 "bootstrap, full process", "held out"))
})

test_that("it names what it re-executed, and what it did not", {
  f <- fp_fixture()
  v <- mm_validate(f$model, f$cohort, B = 15, full_process = TRUE)
  detail <- v$full_process_detail
  expect_true(all(c("knot placement", "datadist", "factor levels") %in%
                    detail$covers))
  note <- v$metrics$note[v$metrics$basis == "bootstrap, full process"]
  expect_match(note, "imputation, selection and tuning are not in this")
})

test_that("resamples that could not be fitted are counted, not hidden", {
  f <- fp_fixture()
  v <- mm_validate(f$model, f$cohort, B = 15, full_process = TRUE)
  detail <- v$full_process_detail
  expect_lte(detail$valid, detail$B)
  expect_match(v$metrics$note[v$metrics$basis == "bootstrap, full process"],
               "of 15 resamples valid")
})

test_that("correcting for optimism moves discrimination down", {
  f <- fp_fixture()
  v <- mm_validate(f$model, f$cohort, B = 30, full_process = TRUE)
  app <- v$metrics$c_stat[v$metrics$basis == "apparent"]
  fp <- v$metrics$c_stat[v$metrics$basis == "bootstrap, full process"]
  expect_lt(fp, app)
})

test_that("a declared cluster is used rather than recorded and ignored", {
  # Same cohort, same model, projects differing only in cluster_id. The
  # cluster was accepted by mm_project() from the start and nothing read it.
  rows <- fp_fixture(cluster = NULL)
  pats <- fp_fixture(cluster = "pid")
  expect_null(rows$model$project$cluster_id)
  expect_equal(pats$model$project$cluster_id, "pid")
  v_rows <- mm_validate(rows$model, rows$cohort, B = 25,
                        full_process = TRUE)
  v_pats <- mm_validate(pats$model, pats$cohort, B = 25,
                        full_process = TRUE)
  expect_null(v_rows$clustered_by)
  expect_equal(v_pats$clustered_by, "pid")
  expect_match(v_pats$metrics$note[v_pats$metrics$basis ==
                                     "bootstrap, full process"],
               "whole pid")
  # The two corrections are computed from different resampling units, so
  # they should not land on the identical number.
  expect_false(identical(
    v_rows$metrics$c_stat[v_rows$metrics$basis == "bootstrap, full process"],
    v_pats$metrics$c_stat[v_pats$metrics$basis == "bootstrap, full process"]))
})
