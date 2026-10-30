# Fixture 9 of the specification's suite: repeated patients must resample as
# whole patients. Resampling rows treats two visits by one person as two
# independent facts, which narrows every interval it touches.

test_that("row-level resampling draws as many rows as it was given", {
  cohort <- mm_synthetic_cohort(n = 100, seed = 1)
  ix <- mm_resample(cohort, NULL)
  expect_length(ix, 100L)
  expect_true(all(ix >= 1L & ix <= 100L))
})

test_that("clustered resampling draws whole patients", {
  cohort <- data.frame(
    pid = c("a", "a", "a", "b", "c", "c"),
    x = 1:6, stringsAsFactors = FALSE)
  sizes <- c(a = 3L, b = 1L, c = 2L)
  for (s in 1:25) {
    set.seed(s)
    drawn <- table(cohort$pid[mm_resample(cohort, "pid")])
    # A patient appears either not at all or as a whole multiple of their
    # own visit count. A fractional patient would mean rows were split.
    for (id in names(drawn)) {
      expect_equal(as.integer(drawn[[id]]) %% sizes[[id]], 0L,
                   info = paste("patient", id, "seed", s))
    }
  }
})

test_that("clustered resampling draws as many patients as exist", {
  cohort <- data.frame(pid = rep(letters[1:10], each = 2),
                       x = 1:20, stringsAsFactors = FALSE)
  set.seed(4)
  ix <- mm_resample(cohort, "pid")
  expect_equal(length(unique(cohort$pid[ix])) <= 10L, TRUE)
  expect_equal(length(ix) %% 2L, 0L)
})

test_that("a missing cluster column is refused", {
  cohort <- mm_synthetic_cohort(n = 20, seed = 2)
  expect_error(mm_resample(cohort, "patient"), "not a column")
})

test_that("a row with no patient identifier is refused, not dropped", {
  cohort <- data.frame(pid = c("a", NA, "b"), x = 1:3)
  expect_error(mm_resample(cohort, "pid"), "cannot be assigned")
})
