# Adversarial cover for the three findings the suite's warning audit produced:
# W-2 (mm_risk_ticks warned twice on an all-missing axis), W-3 (the calculator
# fallback test exercised the wrong branch because assigning an unknown level
# into a factor cell stores NA), and W-4 (the numeric default was returned
# unchecked while the categorical one was validated).
#
# These are deliberately written against the FIXES rather than alongside them:
# each block tries to make the guard wrong in both directions, because a guard
# that is too aggressive is as much a defect as one that is missing, and the
# minimal confirmations written with the fixes could not tell the two apart.
# Synthetic fixtures only; nothing here reads research data.

# ---------------------------------------------------------------- W-2 --------

# Every input with no finite element at all. The guard returns early on each,
# so each must be silent AND empty: silence alone would also be satisfied by a
# guard that returned a tick, which would be worse than the warning it fixed.
mm_adv_unusable_axes <- list(
  "two NAs"          = c(NA_real_, NA_real_),
  "a single NaN"     = NaN,
  "NA and NaN"       = c(NA, NaN),
  "positive Inf"     = Inf,
  "negative Inf"     = -Inf,
  "both infinities"  = c(Inf, -Inf),
  "zero length"      = numeric(0),
  "NULL"             = NULL,
  "logical NA"       = NA,
  "integer NAs"      = c(NA_integer_, NA_integer_),
  "character"        = "a"
)

test_that("an axis with nothing finite on it returns nothing, and quietly", {
  for (nm in names(mm_adv_unusable_axes)) {
    axis <- mm_adv_unusable_axes[[nm]]
    expect_no_warning(mm_risk_ticks(axis))
    expect_length(mm_risk_ticks(axis), 0)
  }
})

test_that("missing values on a usable axis do not disable it", {
  # THE OTHER DIRECTION, and the reason the guard asks any() rather than all():
  # a real lp vector can carry missing values beside usable ones. A guard that
  # refused those would turn the two warnings into a silently blank risk axis
  # on a sheet that should have been drawn, which is the worse failure of the
  # two and the one no minimal confirmation would have caught.
  clean <- mm_risk_ticks(c(-8, 7))
  expect_gte(length(clean), 3)
  expect_identical(mm_risk_ticks(c(NA, -8, 7)), clean)
  expect_identical(mm_risk_ticks(c(-8, 7, NaN)), clean)
  expect_identical(mm_risk_ticks(c(NA, -8, NaN, 7, NA)), clean)
  expect_no_warning(mm_risk_ticks(c(NA, -8, 7)))
  # An integer axis is still an axis.
  expect_identical(mm_risk_ticks(c(-8L, 7L)), clean)
})

test_that("an infinite bound is still refused, and a flat axis too", {
  # The original range check is retained behind the new guard. These inputs
  # pass the guard, so they prove the check behind it still runs rather than
  # having been replaced by it.
  expect_length(mm_risk_ticks(c(-8, 7, Inf)), 0)
  expect_length(mm_risk_ticks(c(-Inf, -8, 7)), 0)
  expect_no_warning(mm_risk_ticks(c(-8, 7, Inf)))
  expect_length(mm_risk_ticks(c(2, 2)), 0)
  expect_length(mm_risk_ticks(rep(0.5, 20)), 0)
})

test_that("a type that cannot be an axis fails loudly rather than silently", {
  # is.finite() is TRUE for a factor, so the guard does not catch one and the
  # range check behind it errors. That is the right outcome and is pinned here
  # so a later widening of the guard cannot quietly turn it into nothing.
  expect_error(mm_risk_ticks(factor(c("a", "b"))))
})

# ------------------------------------------------------------ W-3, W-4 -------

mm_adv_cal_fit <- function() {
  cohort <- mysterymodel::mm_synthetic_cohort(n = 600, seed = 21)
  # "rare" is first for the arithmetic and uncommon in the cohort, so the
  # level the form must NOT open on is also the fallback target. Any test
  # below that passes by accident would have to pass on the wrong level.
  cohort$site <- factor(
    ifelse(seq_len(nrow(cohort)) <= 30, "rare", "usual"),
    levels = c("rare", "usual"))
  project <- mysterymodel::mm_project(
    "uds", "event", c("age", "site"), cohort = cohort)
  suppressWarnings(mysterymodel::mm_model(project, cohort))
}

test_that("no unrecognised level reaches the form, however it is written", {
  fit <- mm_adv_cal_fit()
  levs <- fit$schema$predictors$site$levels
  expect_identical(levs, c("rare", "usual"))
  expect_identical(mm_calculator_defaults(fit)$site, "usual")

  # THE COLUMN IS COERCED TO CHARACTER FIRST on purpose. Writing an unknown
  # level straight into the factor cell stores NA instead, which is how the
  # original version of this test came to exercise the is.na() branch while
  # claiming the not-in-levels branch (finding W-3). Coercing makes the value
  # actually land, so each string below reaches the membership check.
  unknown <- c("vanished", "", " usual", "usual ", "USUAL", "Usual", "usua",
               "usual2", "rare|usual", "NA", "0", "TRUE")
  for (v in unknown) {
    broken <- fit
    broken$datadist$limits$site <- as.character(broken$datadist$limits$site)
    broken$datadist$limits["Adjust to", "site"] <- v
    expect_no_warning(got <- mm_calculator_defaults(broken)$site)
    expect_identical(got, "rare",
                     info = paste0("Adjust to = '", v, "' must not be offered"))
  }
})

test_that("a level that only looks like a level is not accepted", {
  # Spelled out separately from the loop above because this is the property
  # that matters clinically: the match is exact. A case- or whitespace-
  # tolerant comparison would put a value into the form that the fit cannot
  # score, and both spellings below are the ones a human would produce.
  fit <- mm_adv_cal_fit()
  for (v in c("Usual", "USUAL", " usual", "usual\t", "usual\n")) {
    broken <- fit
    broken$datadist$limits$site <- as.character(broken$datadist$limits$site)
    broken$datadist$limits["Adjust to", "site"] <- v
    expect_false(identical(mm_calculator_defaults(broken)$site, "usual"))
  }
  # And the exact spelling still is accepted, so the above is not passing
  # because everything is refused.
  ok <- fit
  ok$datadist$limits$site <- as.character(ok$datadist$limits$site)
  ok$datadist$limits["Adjust to", "site"] <- "usual"
  expect_identical(mm_calculator_defaults(ok)$site, "usual")
})

test_that("a missing or absent categorical default still opens the form", {
  fit <- mm_adv_cal_fit()
  for (v in list(NA, NA_character_, character(0), c("rare", "usual"))) {
    broken <- fit
    broken$datadist$limits$site <- as.character(broken$datadist$limits$site)
    broken$datadist$limits["Adjust to", "site"] <- if (length(v) == 1L) v else NA
    if (!length(v)) broken$datadist$limits["Adjust to", "site"] <- NA
    expect_identical(mm_calculator_defaults(broken)$site, "rare")
  }
})

test_that("a numeric default is inside the range the model was developed on", {
  # FINDING W-4. The categorical branch refused a value the schema did not
  # recognise; this branch returned whatever datadist held. A datadist and a
  # schema can disagree, so the form could open already extrapolating or on a
  # blank field, which is exactly what the in-range assertion elsewhere in the
  # calculator tests promises a reader it does not do.
  fit <- mm_adv_cal_fit()
  rng <- fit$schema$predictors$age$range
  expect_true(all(is.finite(rng)) && rng[1] < rng[2])

  broken_to <- function(v) {
    b <- fit
    b$datadist$limits["Adjust to", "age"] <- v
    expect_no_warning(got <- mm_calculator_defaults(b)$age)
    got
  }
  # Out of range in both directions clamps to the nearer bound, so the opening
  # value stays as close to the fit's own adjust-to as the range allows.
  expect_identical(broken_to(1e6), rng[2])
  expect_identical(broken_to(rng[2] + 0.5), rng[2])
  expect_identical(broken_to(-1e6), rng[1])
  expect_identical(broken_to(rng[1] - 0.5), rng[1])
  # Missing, infinite and non-numeric have no nearer bound, so they fall back
  # to the middle of the developed range: in range by construction, and not a
  # statistic anybody should read as the cohort's median.
  for (v in list(NA_real_, NA, Inf, -Inf, NaN)) {
    got <- broken_to(v)
    expect_true(is.finite(got))
    expect_gte(got, rng[1])
    expect_lte(got, rng[2])
  }
  # An in-range value is returned untouched, so the clamp is not rewriting
  # every default on its way past.
  expect_identical(broken_to(mean(rng)), mean(rng))
  expect_identical(mm_calculator_defaults(fit)$age,
                   unname(fit$datadist$limits["Adjust to", "age"]))
})

test_that("whatever datadist holds, the form opens on a scorable patient", {
  # The end-to-end property the three findings all bear on, and the one worth
  # keeping if the others are ever rewritten: a reader opening the calculator
  # is shown a prediction, not an error, not a blank, and not a figure carrying
  # an extrapolation flag they were never told about.
  skip_if_not_installed("shiny")
  fit <- mm_adv_cal_fit()
  levs <- fit$schema$predictors$site$levels
  rng <- fit$schema$predictors$age$range

  corruptions <- list(
    "clean"            = NULL,
    "unknown level"    = list(site = "vanished"),
    "missing level"    = list(site = NA),
    "age above range"  = list(age = 1e6),
    "age below range"  = list(age = -1e6),
    "age missing"      = list(age = NA_real_),
    "both wrong"       = list(site = "vanished", age = 1e6)
  )
  for (nm in names(corruptions)) {
    b <- fit
    b$datadist$limits$site <- as.character(b$datadist$limits$site)
    for (p in names(corruptions[[nm]])) {
      b$datadist$limits["Adjust to", p] <- corruptions[[nm]][[p]]
    }
    d <- mm_calculator_defaults(b)

    expect_true(d$site %in% levs, info = nm)
    expect_true(is.finite(d$age), info = nm)
    expect_gte(d$age, rng[1])
    expect_lte(d$age, rng[2])

    scored <- mysterymodel::mm_predict(
      fit, as.data.frame(d, stringsAsFactors = FALSE))
    expect_true(is.finite(scored$.pred), info = nm)
    expect_gte(scored$.pred, 0)
    expect_lte(scored$.pred, 1)
    # The form must not open on a patient the model is extrapolating for.
    expect_false(scored$.extrapolated, info = nm)

    # And the value the page submits is the one the defaults chose.
    html <- paste(as.character(mm_calculator_ui(b)), collapse = " ")
    expect_true(grepl(sprintf('value="%s" selected', d$site), html,
                      fixed = TRUE), info = nm)
    expect_false(grepl('value="vanished"', html, fixed = TRUE), info = nm)
  }
})
