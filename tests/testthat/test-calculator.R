test_that("the calculator scores a row exactly as mm_predict does", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  shiny::testServer(mm_calculator(fit), {
    session$setInputs(p1 = 60, p2 = 28, p3 = "female")
    expected <- mm_predict(fit, data.frame(age = 60, bmi = 28, sex = "female"))
    expect_equal(output$probability,
                 sprintf("%.1f%%", 100 * expected$.pred))
    expect_false(grepl("extrapolation", output$extrapolation$html %||% ""))

    # A value outside the development range is scored and labelled, not refused.
    session$setInputs(p1 = 200)
    expect_match(output$extrapolation$html, "extrapolation")

    # A blank number cannot be scored and says so rather than erroring.
    session$setInputs(p1 = NA)
    expect_equal(output$probability, "--")
  })
})

test_that("the form and the reset button share one set of starting values", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  defaults <- mm_calculator_defaults(fit)

  expect_equal(names(defaults), names(fit$schema$predictors))
  # Both halves come from the datadist's "Adjust to" row: the median of a
  # continuous predictor and the commonest level of a categorical one. That
  # is the cohort's most ordinary member, which is where the model is most
  # certain, rather than each factor's first level, which is chosen for the
  # arithmetic and can combine into somebody almost nobody is.
  expect_equal(defaults$age, unname(fit$datadist$limits["Adjust to", "age"]))
  expect_equal(defaults$sex,
               as.character(fit$datadist$limits["Adjust to", "sex"]))
  # A default must be inside the range the model was developed on, or the form
  # would open already extrapolating.
  expect_gte(defaults$age, fit$schema$predictors$age$range[1])
  expect_lte(defaults$age, fit$schema$predictors$age$range[2])

  # The form opens on those values, so the page shows the median patient.
  html <- paste(as.character(mm_calculator_ui(fit)), collapse = " ")
  expect_true(grepl(sprintf('value="%s"', defaults$age), html, fixed = TRUE))
})

test_that("a level the model could not fit never reaches the dropdown", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  cohort$sex <- factor(as.character(cohort$sex),
                       levels = c("female", "male", "unrecorded"))
  project <- mm_project("uds", "event", c("age", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  html <- paste(as.character(mm_calculator_ui(fit)), collapse = " ")

  # Asserted on the submitted value, not the shown text: the label is title
  # cased for the reader and the value stays the level the fit knows.
  expect_true(grepl('value="female"', html, fixed = TRUE))
  expect_true(grepl('value="male"', html, fixed = TRUE))
  expect_true(grepl(">Female<", html, fixed = TRUE))
  # Declared with no rows, so it is absent from the fit and from the schema.
  # Offering it would let a clinician pick a value the model cannot score.
  expect_false(grepl("unrecorded", html, fixed = TRUE))
  # A continuous input states the range it was developed on.
  expect_true(grepl("developed on", html, fixed = TRUE))
})

test_that("the screen carries the adequacy verdict, not just the risk", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  html <- paste(as.character(mm_calculator_ui(fit)), collapse = " ")

  expect_false(fit$adequacy$adequate)
  expect_true(grepl("adequacy-short", html, fixed = TRUE))
  expect_true(grepl(fit$fingerprint, html, fixed = TRUE))
  expect_true(grepl("events per parameter", html, fixed = TRUE))
})

test_that("the bands are cut on the odds ratio against the reference", {
  at <- function(or, t) {
    o <- or * t / (1 - t)
    o / (1 + o)
  }
  lv <- function(p, t = 0.1) mm_calculator_band(p, t)$level

  expect_equal(lv(at(0.49, 0.1)), "well-below")
  expect_equal(lv(at(0.51, 0.1)), "below")
  expect_equal(lv(at(0.99, 0.1)), "below")
  expect_equal(lv(at(1.01, 0.1)), "above")
  expect_equal(lv(at(1.99, 0.1)), "above")
  expect_equal(lv(at(2.01, 0.1)), "well-above")

  # The reference and the odds ratio are both named on screen, so both must
  # appear in the text a clinician reads.
  said <- mm_calculator_band(at(3, 0.1), 0.1)$recommendation
  expect_match(said, "10.0%")
  expect_match(said, "3.00 times the odds")
})

test_that("every band is reachable whatever the event rate", {
  # Found by running the calculator on the ENT applicant cohort, where 62.4%
  # of applicants matched. Cut points at one, two and four times the
  # probability put every patient above the reference in a single band and
  # made the top two unreachable, because twice a 62% rate is not a
  # probability. Odds ratios do not have that problem.
  reachable <- function(t) {
    levels <- vapply(seq(0.001, 0.999, by = 0.001),
                     function(p) mm_calculator_band(p, t)$level, character(1))
    sort(unique(levels))
  }
  all_four <- c("above", "below", "well-above", "well-below")
  expect_equal(reachable(0.093), all_four)
  expect_equal(reachable(0.624), all_four)
  expect_equal(reachable(0.5), all_four)
})

test_that("which end of the colour ramp a band takes is the caller's to say", {
  # Matching into a residency and suffering a complication are both predicted
  # as probabilities, and a high one is good in the first case and bad in the
  # second. The model cannot tell them apart.
  worse <- mm_calculator_band(0.9, 0.3, higher_is = "worse")
  better <- mm_calculator_band(0.9, 0.3, higher_is = "better")

  # Same band, opposite end of the colour ramp. The band's position is
  # carried by the colour and by the sentence; there is no label of its own,
  # because a pill reading WELL BELOW REFERENCE is a verdict printed larger
  # than the number it is about.
  expect_equal(worse$level, better$level)
  expect_equal(worse$odds_ratio, better$odds_ratio)
  expect_equal(worse$color, "#ef4444")
  expect_equal(better$color, "#10b981")
  expect_null(worse$label)
  expect_null(worse$class)
})

test_that("the threshold defaults to the development event rate", {
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("uds", "event", c("age", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  expect_equal(mm_calculator_threshold(fit), fit$adequacy$prevalence)
  expect_equal(mm_calculator_threshold(fit, 0.2), 0.2)
  expect_error(mm_calculator_threshold(fit, 0), "between 0 and 1")
  expect_error(mm_calculator_threshold(fit, 1), "between 0 and 1")
  expect_error(mm_calculator_threshold(fit, c(0.1, 0.2)), "single probability")
})

test_that("the hundred-figure array rounds to whole patients", {
  skip_if_not_installed("shiny")
  band <- mm_calculator_band(0.234, 0.1)
  html <- paste(as.character(mm_calculator_icons(0.234, band)), collapse = " ")
  expect_equal(lengths(regmatches(html, gregexpr("dot-on", html))), 23L)
  expect_match(html, "The model expects 23 of them")
  expect_null(mm_calculator_icons(NA_real_, NULL))
})

test_that("mm_calculator refuses anything but a fitted mm_model", {
  expect_error(mm_calculator(list()), "mm_model")
})

test_that("the page speaks the caller's noun throughout", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("ent", "event", c("age", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  html <- paste(as.character(mm_calculator_ui(fit, subject = "applicant")),
                collapse = " ")

  expect_true(grepl("Applicant values", html, fixed = TRUE))
  # Shiny puts a newline between tag children, so the disclaimer's sentences
  # are matched across whitespace rather than as literals.
  expect_match(html, "this\\s+applicant\\s+beyond the")
  expect_match(html, "applicant\\s+with a missing value")
  # A page about applicants must not be warning about patients.
  expect_false(grepl("patient", html, fixed = TRUE))

  # The sentences the server writes carry it too.
  band <- mm_calculator_band(0.5, 0.1, subject = "applicant")
  expect_match(band$recommendation, "This applicant sits")
  icons <- paste(as.character(mm_calculator_icons(0.2, band, "applicant")),
                 collapse = " ")
  expect_match(icons, "Each dot is one of 100 applicants with these values")

  expect_error(mm_calculator(fit, subject = c("a", "b")), "single word")
})

test_that("the result stays on screen beside a form longer than it is", {
  skip_if_not_installed("shiny")
  # The ENT model has 27 predictors. Scrolling to the last of them left the
  # prediction off the top of the screen with the right-hand half of the page
  # empty, which is the state a calculator is least useful in.
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  html <- paste(as.character(mm_calculator_ui(fit)), collapse = " ")

  expect_true(grepl('class="result-sticky"', html, fixed = TRUE))
  css <- mm_calculator_css()
  expect_match(css, "\\.result-sticky \\{ position: sticky")
  # and released once the columns stack, where sticky would pin the result
  # over the form instead of beside it.
  expect_match(css, "max-width: 991px.*\\.result-sticky \\{ position: static")
})

test_that("the calculator shows the nomogram only once it has been checked", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("ragg")
  cohort <- mm_synthetic_cohort(n = 300, seed = 1)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  drawn <- mm_calculator_nomogram(fit)
  expect_null(drawn$refusal)
  expect_true(file.exists(file.path(
    tempdir(), paste0("mm-nomogram-", substr(fit$fingerprint, 1, 12)),
    "uds_nomogram.png")))

  html <- paste(as.character(mm_calculator_nomogram_panel(drawn)),
                collapse = " ")
  expect_match(html, "nomogram-img")
  # The agreement is the reason the sheet is allowed on the page, so the page
  # states it rather than leaving the reader to take it on trust.
  expect_match(html, "Checked against the model")
  expect_match(html, "reproduces the calculator above")
  expect_match(html, "Reading between the printed ticks costs up to")
  expect_match(html, "bound is larger when a predictor is splined")

  # And the risk axis takes the caller's noun, as the rest of the page does.
  chance <- suppressMessages(
    mm_nomogram(fit, out_dir = NULL, funlabel = "Predicted chance"))
  expect_true("Predicted chance" %in% names(chance$drawn))
})

test_that("a model that cannot be drawn says so in place of the figure", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 600, seed = 3)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        interactions = list(c("age", "bmi")), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  drawn <- mm_calculator_nomogram(fit)
  expect_true(is.character(drawn$refusal))
  html <- paste(as.character(mm_calculator_nomogram_panel(drawn)),
                collapse = " ")
  expect_match(html, "cannot be drawn as a nomogram")
  expect_false(grepl("nomogram-img", html, fixed = TRUE))
})

test_that("the instructions are written for whoever is reading them", {
  skip_if_not_installed("shiny")
  text <- function(...) {
    h <- paste(as.character(mm_calculator_disclaimer(...)), collapse = " ")
    gsub("\\s+", " ", gsub("<[^>]+>", "", h))
  }
  clinician <- text("patient", "clinician")
  self <- text("applicant", "self")

  # A clinician is scoring someone else and is told the number is not advice.
  expect_match(clinician, "It is not advice")
  expect_match(clinician, "knows nothing about this patient")
  # The person the row is about is told something else entirely.
  expect_match(self, "describes people like you, not you")
  expect_match(self, "not a verdict and not a plan")
  expect_match(self, "fitted on people who came before you")
  expect_false(grepl("It is not advice", self, fixed = TRUE))

  # Both are told that performance is not on this screen, and both are told
  # what the interval covers, in the words their own half of the page uses.
  for (t in list(clinician, self)) {
    expect_match(t, "Performance is reported elsewhere")
  }
  expect_match(clinician, "What the interval covers")
  expect_match(self, "The range is the model's, not yours")
  expect_error(mm_calculator_disclaimer("patient", "nobody"), "should be one of")
})

test_that("sentences built around the caller's noun stay grammatical", {
  expect_equal(mm_an("patient"), "a patient")
  expect_equal(mm_an("applicant"), "an applicant")
  expect_equal(mm_an("Infant"), "an Infant")
  expect_equal(mm_an("resident"), "a resident")

  # The seams this exists to close: an article and a plural.
  clinical <- paste(as.character(mm_calculator_disclaimer("applicant")),
                    collapse = " ")
  expect_false(grepl("a applicant", clinical, fixed = TRUE))
  self <- gsub("\\s+", " ", gsub("<[^>]+>", "",
    paste(as.character(mm_calculator_disclaimer("applicant", "self")),
          collapse = " ")))
  expect_match(self, "across applicants who share")
  expect_false(grepl("applicant s", self, fixed = TRUE))
})

test_that("an Hmisc label reaches the form and the nomogram axis alike", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("Hmisc")
  cohort <- mm_synthetic_cohort(n = 300, seed = 1)
  Hmisc::label(cohort$age) <- "Age at surgery (years)"
  # A factor is the case that used to be lost: droplevels(), factor() and
  # relevel() all drop the attribute the label lives in, so a labelled cohort
  # produced a sheet whose continuous axes read as English and whose
  # categorical ones read as column names.
  Hmisc::label(cohort$sex) <- "Sex recorded at birth"
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  expect_equal(fit$schema$predictors$age$label, "Age at surgery (years)")
  expect_equal(fit$schema$predictors$sex$label, "Sex recorded at birth")
  # An unlabelled predictor keeps its column name rather than going blank.
  expect_equal(fit$schema$predictors$bmi$label, "bmi")

  html <- paste(as.character(mm_calculator_ui(fit)), collapse = " ")
  expect_true(grepl("Sex recorded at birth", html, fixed = TRUE))
  expect_true(grepl("Age at surgery (years)", html, fixed = TRUE))

  nom <- suppressMessages(mm_nomogram(fit, out_dir = NULL))
  expect_true(all(c("Age at surgery (years)", "Sex recorded at birth") %in%
                    names(nom$nomogram)))
})

test_that("relabelling an axis cannot change what was verified", {
  cohort <- mm_synthetic_cohort(n = 300, seed = 1)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))

  plain <- suppressMessages(mm_nomogram(fit, out_dir = NULL))
  pretty <- suppressMessages(mm_nomogram(
    fit, out_dir = NULL,
    labels = c(age = "Age (years)", bmi = "Body mass index")))

  # The check runs on the names the fit gave the axes, before any renaming,
  # so the verdict is identical and only the caption moved.
  expect_equal(pretty$worst_disagreement, plain$worst_disagreement)
  expect_equal(pretty$profiles_checked, plain$profiles_checked)
  expect_equal(pretty$reading_error, plain$reading_error)
  expect_true("Age (years)" %in% names(pretty$drawn))
  expect_false("age" %in% names(pretty$drawn))

  expect_error(mm_nomogram(fit, out_dir = NULL, labels = c(nope = "X")),
               "does not have")
  expect_error(mm_nomogram(fit, out_dir = NULL, labels = "Age"),
               "named character vector")
})

test_that("the person the prediction is about gets a different piece of writing", {
  # Not the clinician's sentence with simpler words. Someone reading their own
  # number needs what it counts, what it cannot see, and what to do next.
  self <- mm_calculator_band(0.153, 0.624, "better", "applicant", "self",
                             "matched", 27L)$recommendation
  clin <- mm_calculator_band(0.153, 0.624, "better", "applicant",
                             "clinician")$recommendation

  # A count out of a hundred, twice: the prediction and the reference.
  expect_match(self, "Of 100 applicants who answered this form the way you just did, about 15 matched")
  expect_match(self, "about 62 in 100")
  # No odds ratio. A ratio of odds is not a fact anyone holds about themselves.
  expect_false(grepl("odds", self, fixed = TRUE))
  expect_match(clin, "0.11 times the odds")
  # And none of the jargon the clinical sentence is entitled to use.
  for (word in c("development cohort", "reference of", "Predicted 15.3%")) {
    expect_false(grepl(word, self, fixed = TRUE))
  }

  # It names how little of an application the model saw, which is the
  # strongest honest thing to say about a low prediction.
  expect_match(self, "holds 27 things about you")
  expect_match(self, "not your letters")
  # Without a count it still says so rather than printing a bare number.
  expect_match(mm_calculator_band(0.153, 0.624, "better", "applicant",
                                  "self", "matched")$recommendation,
               "a handful of things about you")

  # It reports and names what the model could not see, and stops there. It
  # does not editorialise about the gap and it does not send the reader off to
  # ask somebody else, which reads as a page declining to answer.
  expect_false(grepl("gap is real", self, fixed = TRUE))
  expect_false(grepl("advises applicant", self, fixed = TRUE))
  expect_match(self, "watch the number move")
})

test_that("a high prediction is not turned into a promise either", {
  high <- mm_calculator_band(0.93, 0.624, "better", "applicant", "self",
                             "matched", 27L)$recommendation
  expect_match(high, "about 93 matched")
  expect_match(high, "most extreme predictions are the ones a model gets least right")
  expect_match(high, "not for fewer applications")

  above <- mm_calculator_band(0.70, 0.624, "better", "applicant", "self",
                              "matched", 27L)$recommendation
  expect_match(above, "a good sign and not a promise")
  expect_match(above, "do not all get there")
})

test_that("the outcome is named rather than called the outcome", {
  skip_if_not_installed("shiny")
  band <- mm_calculator_band(0.2, 0.1, "worse", "patient", "clinician")
  icons <- paste(as.character(
    mm_calculator_icons(0.2, band, "patient", "had a complication")),
    collapse = " ")
  expect_match(icons, "expects 20 of them to have had a complication")

  # The default is the outcome column's name, which `event` overrides.
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("uds", "event", c("age", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  expect_equal(fit$schema$outcome, "event")
})

test_that("a dropdown shows a tidy spelling and submits the level", {
  skip_if_not_installed("shiny")
  expect_equal(mm_title_case("member"), "Member")
  expect_equal(mm_title_case("senior elections"), "Senior Elections")
  expect_equal(mm_title_case("No response"), "No Response")
  # A capital anywhere but the front means the writer meant it.
  expect_equal(mm_title_case("no AOA at school"), "No AOA at School")
  expect_equal(mm_title_case("US Public"), "US Public")
  expect_equal(mm_title_case("pH < 7.3"), "pH < 7.3")
  # Short joining words stay down unless they open or close the phrase.
  expect_equal(mm_title_case("Unable to assess"), "Unable to Assess")
  expect_equal(mm_title_case("Third Highest possible (aka Pass)"),
               "Third Highest Possible (aka Pass)")
  expect_equal(mm_title_case("to"), "To")
  expect_equal(mm_title_case(c("", NA_character_)), c("", NA_character_))

  # The submitted value is untouched. mm_predict() refuses a level it has not
  # seen, and a tidier spelling is exactly that, so the casing is display only.
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  cohort$sex <- factor(ifelse(cohort$sex == "female",
                              "female at birth", "male at birth"))
  project <- mm_project("uds", "event", c("age", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  html <- paste(as.character(mm_calculator_ui(fit)), collapse = " ")

  expect_true(grepl(">Female at Birth<", html, fixed = TRUE))
  expect_true(grepl('value="female at birth"', html, fixed = TRUE))
  expect_false(grepl('value="Female at Birth"', html, fixed = TRUE))

  # And the value the form submits is one the model can actually score.
  expect_silent(mm_predict(fit, data.frame(age = 30, sex = "female at birth")))
  expect_error(mm_predict(fit, data.frame(age = 30, sex = "Female at Birth")),
               "never saw")
})

test_that("the page shows an interval and says what it covers", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  shiny::testServer(mm_calculator(fit), {
    session$setInputs(p1 = 60, p2 = 28, p3 = "female")
    want <- mm_predict(fit, data.frame(age = 60, bmi = 28, sex = "female"),
                       interval = TRUE)
    expect_equal(output$interval,
                 sprintf("95%% CI %.1f%% to %.1f%%",
                         100 * want$.lower, 100 * want$.upper))
    # The point estimate sits inside it.
    expect_gt(want$.pred, want$.lower)
    expect_lt(want$.pred, want$.upper)

    # Nothing to show before every predictor is in.
    session$setInputs(p1 = NA)
    expect_equal(output$interval, "")
  })

  # The caveat no longer apologises for an absence; it says what the interval
  # is and what it leaves out.
  clin <- paste(as.character(mm_calculator_disclaimer("patient", "clinician")),
                collapse = " ")
  expect_match(clin, "uncertainty in the coefficients")
  expect_match(clin, "does not cover which predictors were chosen")
  expect_false(grepl("No interval is shown", clin, fixed = TRUE))

  self <- gsub("\\s+", " ", gsub("<[^>]+>", "", paste(as.character(
    mm_calculator_disclaimer("applicant", "self")), collapse = " ")))
  expect_match(self, "The range is the model's, not yours")
  expect_match(self, "not the range you might fall in")
})

test_that("rows can be kept and compared, which is DynNom's one good idea", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  shiny::testServer(mm_calculator(fit), {
    expect_null(output$comparison$html)

    session$setInputs(p1 = 50, p2 = 25, p3 = "female", save = 1)
    session$setInputs(p1 = 80, save = 2)
    html <- output$comparison$html
    expect_length(gregexpr("compare-row", html)[[1]], 2)

    # A kept row carries the values that produced it, so two of them can be
    # told apart without being read back into the form.
    expect_match(html, "age: 50")
    expect_match(html, "age: 80")

    session$setInputs(clear_saved = 1)
    expect_null(output$comparison$html)

    # A row that cannot be scored is not kept at all rather than kept blank.
    session$setInputs(p1 = NA, save = 3)
    expect_null(output$comparison$html)
  })
})

test_that("a kept row shows its interval and says when it is extrapolated", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 300, seed = 4)
  project <- mm_project("uds", "event", c("age", "bmi"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  keep <- function(age, bmi) {
    row <- data.frame(age = age, bmi = bmi)
    p <- mm_predict(fit, row, interval = TRUE)
    list(values = row, pred = p$.pred, lower = p$.lower, upper = p$.upper,
         extrapolated = p$.extrapolated)
  }
  html <- paste(as.character(mm_calculator_comparison(
    list(keep(50, 25), keep(200, 25)), 0.093, "worse", "patient",
    fit$schema$predictors)), collapse = " ")

  expect_length(gregexpr("compare-row", html)[[1]], 2)
  expect_match(html, "compare-ci")
  expect_match(html, "extrapolated")
  # The common scale is stated, because two bars drawn against different
  # scales are not a comparison.
  expect_match(html, "on a common scale ending at")
  expect_match(html, ">Predictions<")

  expect_null(mm_calculator_comparison(list(), 0.093))
})

test_that("a kept row's bar is placed where the numbers say", {
  skip_if_not_installed("shiny")
  # The first version of this multiplied by 100 twice, so every bar was
  # positioned off the end of its own track and nothing was drawn. The
  # positions are arithmetic and are checked as arithmetic.
  keep <- function(pred, lower, upper) {
    list(values = data.frame(age = 50), pred = pred, lower = lower,
         upper = upper, extrapolated = FALSE)
  }
  html <- paste(as.character(mm_calculator_comparison(
    list(keep(0.10, 0.05, 0.20)), threshold = 0.05)), collapse = " ")

  # The scale ends at four times the reference, stretched if need be so the
  # widest interval is not clipped: max(4 * 0.05, 0.20 * 1.05) = 0.21.
  expect_match(html, "on a common scale ending at 21%")
  expect_match(html, "change a value and see what it moves")
  expect_match(html, sprintf("left: %.4f%%; right: %.4f%%",
                             100 * 0.05 / 0.21, 100 - 100 * 0.20 / 0.21),
               fixed = TRUE)
  expect_match(html, sprintf("left: %.4f%%", 100 * 0.10 / 0.21),
               fixed = TRUE)

  # Nothing is positioned outside its own track, whatever the numbers.
  wide <- paste(as.character(mm_calculator_comparison(
    list(keep(0.99, 0.80, 0.999)), threshold = 0.05)), collapse = " ")
  pcts <- as.numeric(sub("%.*", "", regmatches(wide,
    gregexpr("(?<=left: )[0-9.]+", wide, perl = TRUE))[[1]]))
  expect_true(all(pcts >= 0 & pcts <= 100))
})

test_that("an input another input switches off is parked, not removed", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 400, seed = 9)
  cohort$score_reported <- factor(
    ifelse(seq_len(nrow(cohort)) %% 4 == 0, "Not reported", "Reported"),
    levels = c("Not reported", "Reported"))
  project <- mm_project("uds", "event",
                        c("age", "score_reported", "bmi"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  gate <- list(bmi = list(by = "score_reported", when = "Not reported",
                          value = 28))
  g <- mm_calculator_gates(gate, fit)
  expect_equal(g$bmi$value, 28)
  expect_equal(g$bmi$by_label, "score_reported")

  shut <- paste(as.character(mm_calculator_gated_input(
    "bmi", "p3", fit$schema$predictors$bmi, 28, TRUE, g$bmi)), collapse = " ")
  open <- paste(as.character(mm_calculator_gated_input(
    "bmi", "p3", fit$schema$predictors$bmi, 25, FALSE, g$bmi)), collapse = " ")

  # Shut, not gone. A removed control would leave the predictor missing and
  # the row unscorable, which is the opposite of the point: the form still
  # submits the parked figure.
  expect_match(shut, "<fieldset disabled=\"disabled\"")
  expect_match(shut, 'value="28"')
  expect_match(shut, "Not used while")
  expect_match(shut, "parked at 28")
  expect_false(grepl("fieldset", open, fixed = TRUE))
  expect_match(open, "developed on")

  # The form leaves the slot to the server, because whether it is switched on
  # depends on another input.
  html <- paste(as.character(mm_calculator_ui(fit, gates = g)), collapse = " ")
  expect_match(html, "p3_slot")
})

test_that("a gate is refused when it cannot mean anything", {
  cohort <- mm_synthetic_cohort(n = 300, seed = 9)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))
  g <- function(x) mm_calculator_gates(x, fit)

  expect_equal(g(NULL), list())
  expect_error(g(list(nope = list(by = "sex", when = "male"))),
               "no predictor for")
  expect_error(g(list(sex = list(by = "sex", when = "male"))),
               "gates a categorical predictor")
  expect_error(g(list(bmi = list(by = "age", when = "1"))),
               "not categorical")
  expect_error(g(list(bmi = list(by = "sex", when = "neither"))),
               "must be a level of")
  expect_error(g(list(list(by = "sex", when = "male"))), "named list")

  # Unstated, the parked value is the median the datadist recorded, which is
  # where a parked value is usually put.
  filled <- g(list(bmi = list(by = "sex", when = "male")))
  expect_equal(filled$bmi$value,
               unname(fit$datadist$limits["Adjust to", "bmi"]))
})

test_that("the form opens on the cohort's most ordinary member", {
  skip_if_not_installed("shiny")
  cohort <- mm_synthetic_cohort(n = 600, seed = 21)
  # A level that is first for the arithmetic and rare in the cohort. Opening
  # on it is how the ENT form came to greet every reader as an international
  # graduate on a second attempt with no Step 2 score.
  cohort$site <- factor(
    ifelse(seq_len(nrow(cohort)) <= 30, "rare", "usual"),
    levels = c("rare", "usual"))
  project <- mm_project("uds", "event", c("age", "site"), cohort = cohort)
  fit <- suppressWarnings(mm_model(project, cohort))

  expect_equal(fit$schema$predictors$site$levels[1], "rare")
  expect_equal(mm_calculator_defaults(fit)$site, "usual")

  # The dropdown still lists the levels in the fit's own order; which one is
  # selected is a separate question from which one comes first.
  html <- paste(as.character(mm_calculator_ui(fit)), collapse = " ")
  expect_lt(regexpr('value="rare"', html, fixed = TRUE),
            regexpr('value="usual"', html, fixed = TRUE))
  expect_match(html, 'value="usual" selected')

  # A level the fit never saw cannot be offered, so an "Adjust to" that is
  # not in the schema falls back rather than putting it in the form.
  broken <- fit
  broken$datadist$limits["Adjust to", "site"] <- "vanished"
  expect_equal(mm_calculator_defaults(broken)$site, "rare")
})
