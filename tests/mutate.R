# Standalone fail-closed mutation harness for a testthat R package.
# Adapted from nomogram-final/tests/mutate.R without here or sab().
# Run from a package checkout using an R session, not during R CMD check.
#
# The subprocess writes an RDS receipt. A crash or an absent receipt is
# INVALID, never DETECTED. A red baseline blocks all mutant verdicts.

mm_run_mutant_suite <- function(package_path, test_file, timeout = 180L) {
  bin <- Sys.which("Rscript")
  if (!nzchar(bin)) {
    stop("Rscript is unavailable.", call. = FALSE)
  }
  if (!file.exists(test_file)) {
    return(list(status = "INVALID", failures = NA_integer_,
                reason = "test file does not exist"))
  }
  receipt <- tempfile(fileext = ".rds")
  script <- tempfile(fileext = ".R")
  on.exit(unlink(c(script, receipt)), add = TRUE)
  instructions <- c(
    "argv <- commandArgs(trailingOnly = TRUE)",
    "package_path <- argv[[1]]",
    "test_file <- argv[[2]]",
    "receipt <- argv[[3]]",
    "state <- list(status = 'STARTED', failures = NA_integer_)",
    "saveRDS(state, receipt)",
    "tryCatch({",
    "  pkgload::load_all(package_path, quiet = TRUE)",
    "  state$status <- 'LOADED'",
    "  saveRDS(state, receipt)",
    "  tested <- testthat::test_file(test_file,",
    "                                reporter = 'silent',",
    "                                stop_on_failure = FALSE)",
    "  counts <- as.data.frame(tested)",
    "  if (!nrow(counts)) stop('zero test assertions ran')",
    "  needed <- c('failed', 'error')",
    "  if (!all(needed %in% names(counts))) {",
    "    stop('testthat did not return failure columns')",
    "  }",
    "  state$failures <- as.integer(",
    "    sum(counts$failed) + sum(counts$error))",
    "  if (!'test' %in% names(counts)) {",
    "    stop('testthat did not identify individual tests')",
    "  }",
    "  failed <- counts$failed > 0 | counts$error > 0",
    "  state$failed_tests <- as.character(counts$test[failed])",
    "  state$status <- 'COMPLETED'",
    "  saveRDS(state, receipt)",
    "}, error = function(e) {",
    "  state$reason <- conditionMessage(e)",
    "  saveRDS(state, receipt)",
    "})"
  )
  writeLines(instructions, script)
  ignored <- suppressWarnings(
    system2(bin,
            args = c("--vanilla", shQuote(script),
                     shQuote(normalizePath(package_path)),
                     shQuote(normalizePath(test_file)),
                     shQuote(receipt)),
            stdout = TRUE, stderr = TRUE, timeout = timeout)
  )
  if (!file.exists(receipt)) {
    return(list(status = "INVALID", failures = NA_integer_,
                reason = "no subprocess receipt"))
  }
  outcome <- tryCatch(readRDS(receipt), error = function(e) NULL)
  if (is.null(outcome) ||
      !identical(outcome$status, "COMPLETED") ||
      length(outcome$failures) != 1L ||
      is.na(outcome$failures)) {
    return(list(status = "INVALID", failures = NA_integer_,
                reason = outcome$reason %||%
                  "subprocess did not finish its tests"))
  }
  outcome
}

# A baseline must pass in the same fresh-process environment used for mutants.
assert_green_baseline <- function(package_path, test_file) {
  checked <- mm_run_mutant_suite(package_path, test_file)
  if (!identical(checked$status, "COMPLETED") ||
      !identical(checked$failures, 0L)) {
    stop("Mutation baseline is not green: ",
         checked$status, ", failures: ",
         checked$failures, ". ", checked$reason %||% "",
         call. = FALSE)
  }
  invisible(TRUE)
}

# A single exact-anchor mutation in an already prepared disposable package.
# The caller must supply its own disposable package copy and a targeted test.
mm_apply_mutation <- function(package_path, relative_path, from, to,
                              test_file, expected_test,
                              timeout = 180L) {
  if (!is.character(expected_test) ||
      length(expected_test) != 1L || !nzchar(expected_test)) {
    stop("expected_test must identify the intended detector.",
         call. = FALSE)
  }
  target <- file.path(package_path, relative_path)
  if (!file.exists(target)) {
    return(list(status = "SURVIVED", failures = NA_integer_,
                reason = "target file does not exist"))
  }
  body <- paste(readLines(target, warn = FALSE), collapse = "\n")
  hits <- gregexpr(from, body, fixed = TRUE)[[1]]
  if (identical(hits[1], -1L) || length(hits) != 1L) {
    return(list(status = "SURVIVED", failures = NA_integer_,
                reason = "anchor missing or not unique"))
  }
  writeLines(sub(from, to, body, fixed = TRUE), target)
  checked <- mm_run_mutant_suite(package_path, test_file,
                                  timeout = timeout)
  if (!identical(checked$status, "COMPLETED")) return(checked)
  checked$status <- if (checked$failures > 0L &&
                        expected_test %in% checked$failed_tests) {
    "DETECTED"
  } else {
    "SURVIVED"
  }
  checked
}
