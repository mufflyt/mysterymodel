#!/usr/bin/env Rscript
# External benchmark against a published worked example.
#
# The UCLA graduate admissions logistic regression: 400 applicants, a binary
# admission outcome, GRE, GPA and a four-level institutional rank. Its
# coefficients are published, which makes it the one reference here that is
# not another implementation of the same arithmetic.
#
# The data is NOT vendored into this package. It belongs to UCLA's teaching
# materials and redistributing it under this package's licence would be a
# claim about rights that cannot be checked from here. So this script fetches
# it, checks what it checks, and records the result in inst/decisions.md;
# the invariances it also exercises are tested without it, on synthetic data,
# in tests/testthat/test-ordered-predictors.R.
#
# Run: Rscript data-raw/external_benchmark.R
# Needs: network access to stats.oarc.ucla.edu

suppressPackageStartupMessages({library(rms); library(mysterymodel)})

source_url <- "https://stats.oarc.ucla.edu/stat/data/binary.csv"
message("fetching ", source_url)
cohort <- utils::read.csv(source_url)
stopifnot(nrow(cohort) == 400L, all(c("admit", "gre", "gpa", "rank") %in%
                                      names(cohort)))
cohort$rank_nominal <- factor(cohort$rank, levels = 1:4)
cohort$rank_ordered <- ordered(cohort$rank, levels = 1:4)
cohort$rank_score <- as.numeric(cohort$rank)
message(nrow(cohort), " rows, ", sum(cohort$admit), " admitted")

# Published to five decimal places, so the tolerance is the printing and not
# the arithmetic: a number given to 1e-5 cannot witness agreement to 1e-10.
published <- c("(Intercept)" = -3.98998, gre = 0.00226, gpa = 0.80404,
               rank_nominal2 = -0.67544, rank_nominal3 = -1.34020,
               rank_nominal4 = -1.55146)
published_tolerance <- 1e-4
engine_tolerance <- 1e-6

reference <- stats::glm(admit ~ gre + gpa + rank_nominal, data = cohort,
                        family = stats::binomial())
dd <- rms::datadist(cohort)
old <- options(datadist = dd)
on.exit(options(old), add = TRUE)
engine <- rms::lrm(admit ~ gre + gpa + rank_nominal, data = cohort,
                   x = TRUE, y = TRUE)
project <- mm_project("ucla", "admit", c("gre", "gpa", "rank_nominal"),
                      positive_class = 1, cohort = cohort, seed = 1978)
ours <- suppressWarnings(mm_model(project, cohort))

risk <- list(glm = unname(stats::predict(reference, type = "response")),
             rms = unname(stats::predict(engine, type = "fitted")),
             mysterymodel = mm_predict(ours, cohort)$.pred)

checks <- data.frame(
  check = c("published coefficients, glm",
            "published coefficients, mysterymodel",
            "glm against rms, probabilities",
            "glm against mysterymodel, probabilities",
            "baseline level is rank 1"),
  worst = c(
    max(abs(stats::coef(reference)[names(published)] - published)),
    max(abs(unname(stats::coef(ours$fit)) -
              unname(stats::coef(reference)))),
    max(abs(risk$glm - risk$rms)),
    max(abs(risk$glm - risk$mysterymodel)),
    as.numeric(ours$schema$predictors$rank_nominal$levels[1] != "1")),
  tolerance = c(published_tolerance, engine_tolerance, engine_tolerance,
                engine_tolerance, 0),
  stringsAsFactors = FALSE)
checks$passed <- checks$worst <= checks$tolerance
print(checks, row.names = FALSE)

if (!all(checks$passed)) {
  stop("external benchmark failed: ",
       paste(checks$check[!checks$passed], collapse = "; "), call. = FALSE)
}
message("all external benchmark checks passed")
