testthat::test_that("IECV requires multiple valid clusters", {
  cohort <- data.frame(
    event = rep(c(0L, 1L), 20),
    age = seq_len(40), site = rep("one", 40)
  )
  project <- mysterymodel::mm_project(
    "iecv-adversarial", "event", "age", cohort = cohort
  )
  testthat::expect_error(
    mysterymodel::mm_iecv(
      project, cohort, "site", min_val = 5, min_events = 2
    ),
    "two or more"
  )
})
testthat::test_that("IECV refuses undersized holdout rather than skip", {
  cohort <- data.frame(
    event = rep(c(0L, 1L), 40),
    age = seq_len(80),
    site = rep(c("small", "large"), times = c(10, 70))
  )
  project <- mysterymodel::mm_project(
    "iecv-size", "event", "age", cohort = cohort
  )
  testthat::expect_error(
    mysterymodel::mm_iecv(
      project, cohort, "site", min_val = 30, min_events = 2
    ),
    "minimum"
  )
})
testthat::test_that("IECV prevents patients in both partitions", {
  cohort <- data.frame(
    event = rep(c(0L, 1L), 40),
    age = seq_len(80),
    site = rep(c("a", "b"), each = 40),
    patient = rep(paste0("p", seq_len(40)), times = 2)
  )
  project <- mysterymodel::mm_project(
    "iecv-patient", "event", "age", cohort = cohort,
    cluster_id = "patient"
  )
  testthat::expect_error(
    mysterymodel::mm_iecv(
      project, cohort, "site", min_val = 10, min_events = 2
    ),
    "training and holdout"
  )
})
testthat::test_that("TRIPOD checklist never invents missing evidence", {
  fixture <- tempfile("tripod")
  dir.create(fixture)
  on.exit(unlink(fixture, recursive = TRUE), add = TRUE)
  utils::write.csv(
    data.frame(n = 125L), file.path(fixture, "counts.csv"),
    row.names = FALSE
  )
  manifest <- data.frame(
    item = c("Sample size", "Ethics approval"),
    status = c("Met", "Not reported"),
    artifact = c("counts.csv", NA_character_),
    column = c("n", NA_character_),
    row = c(1L, NA_integer_),
    reason = c("", ""),
    stringsAsFactors = FALSE
  )
  checked <- mysterymodel::mm_tripod_checklist(manifest, fixture)
  testthat::expect_identical(checked$verified_value[[1]], "125")
  testthat::expect_identical(
    checked$status[[2]], "Not reported"
  )
  manifest$artifact[[1]] <- "missing.csv"
  testthat::expect_error(
    mysterymodel::mm_tripod_checklist(manifest, fixture),
    "Missing written evidence"
  )
})
testthat::test_that("TRIPOD never allows unsupported N/A", {
  manifest <- data.frame(
    item = "Ethics approval", status = "N/A",
    artifact = NA_character_, column = NA_character_,
    row = NA_integer_, reason = "",
    stringsAsFactors = FALSE
  )
  testthat::expect_error(
    mysterymodel::mm_tripod_checklist(manifest, tempdir()),
    "explicit justification"
  )
})
