# pkgdown refuses to build a site when an exported topic is missing from the
# curated reference index in _pkgdown.yml, and nothing in the package noticed.
# The site had been failing in CI since the accessors were added: the topic
# mm_model-accessors was never listed, so eleven ported functions later the
# failure named twelve topics at once and the oldest was weeks old.
#
# A documentation index is the one artefact that cannot be checked by using the
# package, so it is checked here instead.
#
# STRUCTURAL, SO IT SKIPS ON AN INSTALLED TREE: R CMD check runs the suite
# against the installed package, which has neither man/ nor _pkgdown.yml.

pkgdown_root <- function() {
  p <- testthat::test_path("..", "..")
  if (file.exists(file.path(p, "_pkgdown.yml")) &&
      dir.exists(file.path(p, "man"))) p else NA_character_
}

documented_topics <- function(root) {
  out <- character(0)
  for (f in list.files(file.path(root, "man"), "[.]Rd$", full.names = TRUE)) {
    ln <- readLines(f, warn = FALSE)
    # @keywords internal is how a topic opts out of the index, so an internal
    # helper is not a gap.
    if (any(grepl("keyword{internal}", ln, fixed = TRUE))) next
    hit <- ln[startsWith(ln, "\\name{")][1]
    if (is.na(hit)) next
    out <- c(out, substr(hit, 7L, nchar(hit) - 1L))
  }
  out
}

indexed_topics <- function(root) {
  yml <- readLines(file.path(root, "_pkgdown.yml"), warn = FALSE)
  # HYPHENS ARE LEGAL IN A TOPIC NAME, and mm_model-accessors is one of them,
  # so the character class has to admit them or the gate reports a topic as
  # unlisted while it sits in the file.
  trimws(sub("^[[:space:]]*-[[:space:]]+", "",
             grep("^[[:space:]]*-[[:space:]]+[A-Za-z._][A-Za-z0-9._-]*[[:space:]]*$",
                  yml, value = TRUE)))
}

test_that("every documented topic appears in the pkgdown reference index", {
  root <- pkgdown_root()
  skip_if(is.na(root), "source tree not present (installed-package check)")
  missing <- setdiff(documented_topics(root), indexed_topics(root))
  expect_identical(missing, character(0),
                   info = paste("topics missing from _pkgdown.yml:",
                                paste(missing, collapse = ", ")))
})

test_that("the index does not list a topic that has no documentation", {
  # The other direction, which pkgdown also refuses: a renamed or deleted
  # function leaves its name behind in the index.
  root <- pkgdown_root()
  skip_if(is.na(root), "source tree not present (installed-package check)")
  rd <- sub("[.]Rd$", "", list.files(file.path(root, "man"), "[.]Rd$"))
  articles <- sub("[.]Rmd$", "",
                  list.files(file.path(root, "vignettes"), "[.]Rmd$"))
  stale <- setdiff(indexed_topics(root), c(rd, articles))
  expect_identical(stale, character(0),
                   info = paste("listed but undocumented:",
                                paste(stale, collapse = ", ")))
})
