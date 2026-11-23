# Non-gating README fact probe. Prints observed repository counts.
# No numbers are hard-coded as expected values.
mm_readme_facts <- function(package_root = ".") {
  if (!file.exists(file.path(package_root, "DESCRIPTION"))) {
    stop("Not an R package root.", call. = FALSE)
  }
  root <- normalizePath(package_root, mustWork = TRUE)
  count <- function(dir, pattern = NULL) {
    folder <- file.path(root, dir)
    if (!dir.exists(folder)) return(0L)
    length(list.files(folder, pattern = pattern,
                      recursive = TRUE, all.files = FALSE))
  }
  fields <- read.dcf(file.path(root, "DESCRIPTION"))
  info <- data.frame(
    fact = c("Package", "Version", "R source files",
             "testthat R files", "vignettes", "documentation files"),
    observed = as.character(c(
      fields[1, "Package"], fields[1, "Version"],
      count("R", "[.]R$"), count("tests/testthat", "[.]R$"),
      count("vignettes", "[.]Rmd$"),
      count("man", "[.]Rd$")
    )),
    stringsAsFactors = FALSE
  )
  print(info, row.names = FALSE)
  base::message("README fact probe only: review prose for discrepancies.")
  invisible(info)
}
