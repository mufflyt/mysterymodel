#!/usr/bin/env Rscript
# Measure the countable claims the documentation makes about this package, and
# say whether the documentation still states them.
#
#   Rscript tools/measure-facts.R              counts only, fast
#   Rscript tools/measure-facts.R --assertions also runs the suite
#
# WHY THIS PRINTS AND DOES NOT FAIL. A per-number expectation is one more thing
# to update whenever a test is added, and the pressure under that friction runs
# one way: the expected number gets edited until the build is green, which is
# the drift wearing a test. So this reports and a human decides.
#
# WHY IT CHECKS THE DOCUMENTS TOO. A probe that only prints correct numbers
# cannot show that the README contains them, which is the whole failure it
# exists to catch. On 2026-11-22 the README claimed eleven exported functions,
# 318 test blocks, 1301 assertions and 25 files, and the validation appendix
# claimed 24 files, 271 blocks, 1079 assertions, 10 exports and 15 source
# files. Every one of those was wrong, and none sat inside a test contract, so
# nothing failed for weeks. Each measured value below is therefore searched for
# in the documents that quote it.
#
# Assertions are counted against the SOURCE tree. `R CMD check` runs the suite
# against the installed package, where the structural blocks that read `R/`,
# `_pkgdown.yml` and `review/` cannot see them and skip, so its total is lower
# by construction. The two are different numbers and neither is wrong.

root <- normalizePath(".", mustWork = TRUE)
want_assertions <- "--assertions" %in% commandArgs(trailingOnly = TRUE)

read_lines <- function(...) {
  p <- file.path(root, ...)
  if (!file.exists(p)) character(0) else readLines(p, warn = FALSE)
}

namespace <- read_lines("NAMESPACE")
r_files <- list.files(file.path(root, "R"), "[.]R$")
test_files <- list.files(file.path(root, "tests", "testthat"),
                         "^test-.*[.]R$")

internal <- unique(unlist(lapply(
  list.files(file.path(root, "R"), "[.]R$", full.names = TRUE),
  function(f) {
    ln <- readLines(f, warn = FALSE)
    hits <- grep("^mm_[a-zA-Z0-9_.]+ <- function", ln, value = TRUE)
    sub(" <- function.*$", "", hits)
  })))

blocks <- sum(vapply(
  list.files(file.path(root, "tests", "testthat"), "^test-.*[.]R$",
             full.names = TRUE),
  function(f) sum(grepl("test_that(", readLines(f, warn = FALSE),
                        fixed = TRUE)),
  numeric(1)))

facts <- list(
  "exported functions" = sum(startsWith(namespace, "export(")),
  "registered S3 methods" = sum(startsWith(namespace, "S3method(")),
  "internal mm_ functions" = length(internal),
  "source files in R/" = length(r_files),
  "test files" = length(test_files),
  "test blocks" = blocks
)

if (want_assertions) {
  base::message("running the suite for the assertion count")
  res <- testthat::test_local(path = root,
                              reporter = testthat::SilentReporter$new(),
                              stop_on_failure = FALSE)
  d <- as.data.frame(res)
  facts[["assertions"]] <- sum(d$nb)
  facts[["failures"]] <- sum(d$failed) + sum(d$error)
  facts[["skips"]] <- sum(d$skipped)
}

# The documents that quote these numbers. A measured value is "stated" when the
# number appears somewhere in the file; this cannot tell WHICH claim it belongs
# to, so it finds silence and drift, not a mislabelled figure.
docs <- c("README.md", file.path("inst", "validation-appendix.md"))
doc_text <- lapply(docs, function(f) paste(read_lines(f), collapse = "\n"))
names(doc_text) <- docs

cat("\nmeasured facts\n")
for (nm in names(facts)) {
  v <- facts[[nm]]
  found <- vapply(doc_text, function(txt)
    grepl(paste0("\\b", format(v, scientific = FALSE), "\\b"), txt),
    logical(1))
  where <- if (all(!found)) "stated in neither document"
    else paste("stated in", paste(docs[found], collapse = ", "))
  cat(sprintf("  %-24s %6s   %s\n", nm, format(v), where))
}

cat("\ncounted phrases that match no measured value, for a human to read\n")
# PRESENTED WITH THEIR PHRASE RATHER THAN ADJUDICATED. A prose count can be
# about a subset ("41 blocks across two files" is the saboteur suites, not the
# suite) and no rule here can tell that from drift. Printing the phrase is what
# makes the list reviewable instead of noise someone learns to skip.
measured <- vapply(facts, function(v) format(v, scientific = FALSE),
                   character(1))
for (f in docs) {
  ln <- read_lines(f)
  # The leading boundary matters: without it "S3 methods" reads as "3 methods"
  # and the probe reports a drift it invented.
  pat <- paste0("\\b[0-9]+ (exported|export|functions|methods|test blocks|",
                "test files|tests|blocks|assertions|source files|files)")
  phrases <- unique(unlist(regmatches(ln, gregexpr(pat, ln))))
  odd <- phrases[!vapply(phrases, function(ph)
    sub(" .*$", "", ph) %in% measured, logical(1))]
  cat(sprintf("  %s\n", f))
  if (!length(odd)) {
    cat("    every counted phrase uses a value measured above\n")
  } else {
    for (o in odd) cat(sprintf("    %s\n", o))
  }
}
if (!want_assertions) {
  cat("\nAssertion and failure counts were not measured in this run, so a\n",
      "claim about them cannot be checked and appears above unmatched.\n",
      "Pass --assertions to measure them.\n", sep = "")
}
cat("\nThis is a probe. It reports; it does not fail.\n")
