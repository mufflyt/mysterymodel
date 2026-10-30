# What the c-statistic's interval is allowed to claim. Every expectation here
# compares against an independent pROC call rather than against a recorded
# number, so a change of method fails the file even if the figures look
# reasonable.

ci_from_proc <- function(p, y) {
  roc <- pROC::roc(y, p, quiet = TRUE, direction = "<")
  ci <- suppressWarnings(as.numeric(pROC::ci.auc(roc)))
  list(c = as.numeric(roc$auc), lower = ci[1], upper = ci[3])
}

row_for <- function(p, y, ...) {
  suppressWarnings(mysterymodel:::mm_metrics(p, y, basis = "probe", ...))
}

test_that("an outcome that does not vary yields no c-statistic at all", {
  # Not an interval of width zero, and not 0.5: the quantity is undefined,
  # because there is no pair of one event and one non-event to order.
  for (y in list(c(0, 0, 0, 0), c(1, 1, 1, 1))) {
    row <- row_for(c(0.1, 0.4, 0.6, 0.9), y)
    expect_true(is.na(row$c_stat))
    expect_true(is.na(row$c_lower))
    expect_true(is.na(row$c_upper))
    expect_match(row$note, "does not vary")
    expect_match(row$note, "discrimination is undefined")
  }
  expect_equal(row_for(c(0.1, 0.4, 0.6, 0.9), c(0, 0, 0, 0))$non_events, 4L)
})

test_that("one of either class gives the estimate and no interval", {
  # DeLong needs two of each. The c-statistic itself is perfectly calculable
  # from one event, and withholding it along with its interval would discard
  # a number the data supports.
  set.seed(1978)
  for (k in list(list(c(0.9, runif(40)), c(1, rep(0, 40))),
                 list(c(0.1, runif(40)), c(0, rep(1, 40))))) {
    row <- row_for(k[[1]], k[[2]])
    ref <- ci_from_proc(k[[1]], k[[2]])
    expect_equal(row$c_stat, ref$c)
    expect_false(is.na(row$c_stat))
    expect_true(is.na(ref$lower))
    expect_true(is.na(row$c_lower))
    expect_true(is.na(row$c_upper))
    expect_match(row$note, "no interval here")
    expect_match(row$note, "at least two of each outcome")
    # And it says what it had, rather than leaving the reader to count.
    expect_match(row$note, "1 event\\(s\\)|40 event\\(s\\)")
  }
})

test_that("two of each is enough, and the interval is pROC's", {
  set.seed(1978)
  p <- c(0.9, 0.8, runif(40)); y <- c(1, 1, rep(0, 40))
  row <- row_for(p, y)
  ref <- ci_from_proc(p, y)
  expect_equal(row$c_stat, ref$c)
  expect_equal(row$c_lower, ref$lower)
  expect_equal(row$c_upper, ref$upper)
  expect_match(row$note, "95% DeLong interval")
  expect_match(row$note, "from 2 event\\(s\\) and 40 non-event\\(s\\)")
})

test_that("a rare outcome reports what its interval rests on", {
  # Three events among three hundred rows give a computable interval and a
  # fragile one. No threshold is imposed, because the package has no evidence
  # for one; the counts that govern the standard error are stated instead.
  set.seed(1978)
  p <- c(0.9, 0.85, 0.8, runif(297)); y <- c(1, 1, 1, rep(0, 297))
  row <- row_for(p, y)
  ref <- ci_from_proc(p, y)
  expect_equal(c(row$c_lower, row$c_upper), c(ref$lower, ref$upper))
  expect_equal(row$events, 3L)
  expect_equal(row$non_events, 297L)
  expect_match(row$note, "from 3 event\\(s\\) and 297 non-event\\(s\\)")
  expect_no_match(row$note, "zero width")
})

test_that("a zero-width interval is reported as the absence it is", {
  # Perfect separation and complete ties both drive DeLong's standard error
  # to zero. The interval is returned as pROC computes it, and said out loud,
  # because [1, 1] beside a held-out interval reads as certainty.
  set.seed(1978)
  perfect <- list(p = c(runif(30, 0, 0.4), runif(30, 0.6, 1)),
                  y = rep(0:1, each = 30))
  tied <- list(p = rep(0.3, 40), y = rep(0:1, 20))
  for (k in list(perfect, tied)) {
    row <- row_for(k$p, k$y)
    ref <- ci_from_proc(k$p, k$y)
    expect_equal(row$c_lower, ref$lower)
    expect_equal(row$c_upper, ref$upper)
    expect_equal(row$c_upper - row$c_lower, 0)
    expect_match(row$note, "zero width")
    expect_match(row$note, "not a statement of precision")
  }
  expect_equal(row_for(perfect$p, perfect$y)$c_stat, 1)
  expect_equal(row_for(tied$p, tied$y)$c_stat, 0.5)
})

test_that("a limit truncated at the parameter space says so", {
  # Deterministic, and chosen so the interval is wide rather than degenerate:
  # two events high but not above every non-event, so DeLong is estimable and
  # its upper limit runs past 1, where pROC truncates it.
  p <- c(0.9, 0.6, seq(0, 0.75, length.out = 40))
  y <- c(1, 1, rep(0, 40))
  row <- row_for(p, y)
  expect_equal(row$c_stat, 0.9)
  expect_equal(row$c_upper, 1)
  expect_gt(row$c_upper - row$c_lower, 0.3)
  expect_match(row$note, "bound and not an estimate")
  # A comfortable interval claims nothing of the kind.
  set.seed(4)
  y2 <- rbinom(400, 1, 0.3); p2 <- stats::plogis(-1 + 1.5 * y2 + rnorm(400))
  ordinary <- row_for(p2, y2)
  expect_gt(ordinary$c_lower, 0)
  expect_lt(ordinary$c_upper, 1)
  expect_no_match(ordinary$note, "bound and not an estimate")
  expect_no_match(ordinary$note, "zero width")
})

# The c-statistic from its definition: over every event / non-event pair, the
# proportion where the event scores higher, counting a tie as half a pair.
# Written out rather than taken from another package, so the comparison is
# against the quantity and not against a second implementation of it.
concordance_by_hand <- function(p, y) {
  events <- p[y == 1L]
  non_events <- p[y == 0L]
  pairs <- outer(events, non_events, "-")
  (sum(pairs > 0) + 0.5 * sum(pairs == 0)) / length(pairs)
}

test_that("tied predictions are handled one way everywhere", {
  set.seed(11)
  y <- rbinom(300, 1, 0.25)
  p <- round(stats::plogis(-1 + 1.4 * y + rnorm(300)), 1)
  expect_lt(length(unique(p)), 15L)
  row <- row_for(p, y)
  expect_equal(row$c_stat, ci_from_proc(p, y)$c)
  # Half credit for a tie is what makes the reported figure the Mann-Whitney
  # statistic, and it is the convention rms's Dxy is on too, so the apparent
  # row and the corrected row beneath it are on one scale.
  expect_equal(row$c_stat, concordance_by_hand(p, y), tolerance = 1e-12)

  # Every prediction tied is the degenerate end of the same rule.
  expect_equal(concordance_by_hand(rep(0.3, 40), rep(0:1, 20)), 0.5)

  # And a predictor pointing the wrong way is scored below 0.5 rather than
  # silently flipped, which is what direction = "<" fixes in place.
  expect_lt(row_for(1 - p, y)$c_stat, 0.5)
  expect_equal(row_for(1 - p, y)$c_stat,
               concordance_by_hand(1 - p, y), tolerance = 1e-12)
})

test_that("a corrected c-statistic is never given an apparent interval", {
  cohort <- mm_synthetic_cohort(n = 300, prevalence = 0.12, seed = 1978)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort,
                        split_var = "year", split_at = 2023)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- suppressWarnings(mm_validate(model, cohort, B = 20,
                                    full_process = TRUE))

  corrected <- v$metrics[grepl("^bootstrap", v$metrics$basis), ]
  expect_equal(nrow(corrected), 2L)
  expect_true(all(is.na(corrected$c_lower)))
  expect_true(all(is.na(corrected$c_upper)))
  expect_true(all(grepl("No interval", corrected$note)))
  expect_true(all(grepl("nested bootstrap", corrected$note)))

  # The apparent interval exists and belongs to the apparent row only.
  app <- v$metrics[v$metrics$basis == "apparent", ]
  expect_false(is.na(app$c_lower))
  expect_match(app$note, "95% DeLong interval")

  # The printed table carries the same distinction, so a reader of the
  # console sees it without opening the note column.
  printed <- paste(capture.output(print(v)), collapse = "\n")
  expect_match(printed, "no interval, see note")
  expect_match(printed, "DeLong")
})

test_that("every basis reports the two counts its discrimination rests on", {
  cohort <- mm_synthetic_cohort(n = 300, prevalence = 0.12, seed = 1978)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = cohort,
                        split_var = "year", split_at = 2023)
  model <- suppressWarnings(mm_model(project, cohort, nonlinear = "age"))
  v <- suppressWarnings(mm_validate(model, cohort, B = 20))

  expect_true("non_events" %in% names(v$metrics))
  expect_equal(v$metrics$non_events, v$metrics$n - v$metrics$events)

  # The held-out row counts its own eligible rows, not the development ones.
  held <- v$metrics[v$metrics$basis == "held out", ]
  outside <- cohort[cohort$year >= 2023, , drop = FALSE]
  expect_equal(held$n, nrow(outside))
  expect_equal(held$events, sum(outside$event))
  expect_equal(held$non_events, sum(outside$event == 0))
  expect_match(held$note, "scored once")
  expect_match(held$note, "95% DeLong interval")
})

# End to end, because a reader meets these through mm_validate() and not
# through mm_metrics(). Each of these is a cohort that produces a number which
# looks better than the evidence behind it.

test_that("saboteur: a perfectly separating predictor cannot look precise", {
  # A predictor that all but reproduces the outcome drives the apparent
  # c-statistic to 1 and DeLong's standard error to 0. Without the
  # disclosure the apparent row reads 1.0000 (1.0000-1.0000), which is the
  # most confident claim the table can make and rests on nothing.
  cohort <- mm_synthetic_cohort(n = 200, seed = 5)
  cohort$marker <- cohort$event + stats::rnorm(200, 0, 0.001)
  project <- mm_project("uds", "event", c("marker", "age"),
                        positive_class = 1, seed = 1978)
  model <- suppressWarnings(mm_model(project, cohort, check_leakage = FALSE))
  v <- suppressWarnings(mm_validate(model, cohort, B = 5))
  app <- v$metrics[v$metrics$basis == "apparent", ]

  expect_gt(app$c_stat, 0.99)
  if (isTRUE(all.equal(app$c_upper - app$c_lower, 0))) {
    expect_match(app$note, "zero width")
    expect_match(paste(capture.output(print(v)), collapse = " "),
                 "zero width, see note")
  } else {
    expect_match(app$note, "95% DeLong interval")
  }
})

test_that("saboteur: a held-out cohort with one event is not given one", {
  # The commonest way an external validation flatters itself is a split that
  # leaves almost no events on the far side. The row is kept, the estimate is
  # kept, and the interval is refused with its reason.
  cohort <- mm_synthetic_cohort(n = 400, prevalence = 0.1, seed = 3)
  cohort$year <- 2019L
  held <- cohort[cohort$event == 1, ][1, , drop = FALSE]
  held <- rbind(held, utils::head(cohort[cohort$event == 0, ], 30))
  held$year <- 2024L
  mixed <- rbind(cohort, held)
  project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                        positive_class = 1, cohort = mixed,
                        split_var = "year", split_at = 2024)
  model <- suppressWarnings(mm_model(project, mixed, nonlinear = "age"))
  v <- suppressWarnings(mm_validate(model, mixed, B = 5))

  row <- v$metrics[v$metrics$basis == "held out", ]
  expect_equal(row$events, 1L)
  expect_equal(row$non_events, 30L)
  expect_false(is.na(row$c_stat))
  expect_true(is.na(row$c_lower))
  expect_match(row$note, "at least two of each outcome")
  expect_match(row$note, "1 event\\(s\\) and 30 non-event\\(s\\)")
})
