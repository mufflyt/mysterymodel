# Synthetic-only, deterministic adversarial fixture helpers.
mm_adv_fixture <- function(n = 500L, seed = 4141L) {
  base::message("Adversarial fixture: n=", n, "; seed=", seed)
  cohort <- mysterymodel::mm_synthetic_cohort(n = n, seed = seed)
  needed <- c("event", "age", "bmi", "sex")
  testthat::expect_true(all(needed %in% names(cohort)))
  project <- mysterymodel::mm_project(
    "adversarial", "event", c("age", "bmi", "sex"),
    cohort = cohort
  )
  fit <- suppressWarnings(mysterymodel::mm_model(project, cohort))
  base::message("Fitted adversarial cohort: ", fit$n_dev, " rows")
  list(cohort = cohort, project = project, fit = fit)
}

mm_adv_profiles <- function(fixture, n = 12L) {
  vars <- fixture$project$predictors
  fixture$cohort[base::seq_len(n), vars, drop = FALSE]
}

mm_adv_no_skips <- function(test_name, observed) {
  testthat::expect_true(
    isTRUE(observed),
    info = paste("Mandatory contract not satisfied:", test_name)
  )
}
