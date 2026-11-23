# Two defects that the mutation campaign proved nothing in this package could
# catch. Both are written from a demonstrated failure, not from a worry.
#
# M07: every S3 method this package defines must be REGISTERED, not merely
#      present in the namespace.
# M09: the schema must describe the population the model was FITTED on, not
#      the population that was supplied.

test_that("M07: every defined S3 method is registered, not just defined", {
  # WHY THE OBVIOUS TEST CANNOT WORK. Deleting S3method(coef,mm_model) from
  # NAMESPACE makes coef() return NULL for a real user, and yet:
  #   - test_local() misses it, because pkgload loads with export_all = TRUE
  #   - R CMD check misses it too, because test_check() evaluates tests in an
  #     environment inheriting the package namespace, so UseMethod() finds
  #     coef.mm_model by NAME even with no registration
  # Both lanes were run against the mutant and both passed. The registration
  # table is the one thing name lookup cannot mask, so it is read directly.
  ns <- asNamespace("mysterymodel")
  reg <- getNamespaceInfo(ns, "S3methods")
  registered <- paste(reg[, 1], reg[, 2], sep = ".")

  # Every function named generic.class in the namespace, for the classes this
  # package owns, has to appear in that table.
  owned <- c("mm_model", "mm_project", "mm_cohort", "mm_eda", "mm_adequacy",
             "mm_validation", "mm_nomogram", "mm_splines",
             "mm_interaction_screen", "summary.mm_model")
  defined <- character(0)
  for (nm in ls(ns, all.names = TRUE)) {
    for (cls in owned) {
      if (endsWith(nm, paste0(".", cls)) &&
          is.function(get(nm, envir = ns))) {
        defined <- c(defined, nm)
      }
    }
  }
  expect_gt(length(defined), 10L)
  missing <- setdiff(defined, registered)
  expect_identical(missing, character(0),
                   info = paste("defined but not registered:",
                                paste(missing, collapse = ", ")))
})

test_that("M09: the schema describes the fitted population, not the supplied one", {
  # The campaign's original fixture was complete-case, so dev and supplied
  # were the same object and the mutation was inert. This is the targeted
  # fixture that makes the difference observable: the rows holding bmi's
  # extremes are incomplete in a DIFFERENT predictor, so complete-case
  # filtering drops them and the fitted range is genuinely narrower.
  #
  # Measured on the mutant (schema built from `supplied`):
  #   schema bmi range 15 to 47.2 instead of 15 to 45.7, and the patient at
  #   47.2 came back flagged extrapolated = FALSE instead of TRUE.
  # A schema built before filtering therefore switches off extrapolation
  # warnings for exactly the patients outside the fitted population.
  co <- mm_synthetic_cohort(n = 400, prevalence = 0.15, seed = 11)
  extremes <- c(which.min(co$bmi), which.max(co$bmi))
  co$sex[extremes] <- NA
  pr <- mm_project("m09", "event", c("age", "bmi", "sex"),
                   positive_class = "1", cohort = co)
  m <- suppressWarnings(mm_model(pr, co))

  expect_gt(m$n_supplied, m$n_dev)

  # the schema's range is the DEVELOPMENT range, strictly inside the supplied one
  sch <- m$schema$predictors$bmi$range
  expect_lt(max(sch), max(co$bmi, na.rm = TRUE))

  # and the consequence a clinician would see: the out-of-range patient is
  # flagged. This is the assertion the mutation flipped.
  probe <- co[extremes[2], , drop = FALSE]
  probe$sex <- stats::na.omit(unique(co$sex))[1]
  expect_true(mm_predict(m, probe)$.extrapolated[1])
})
