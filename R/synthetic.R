#' Generate a synthetic cohort resembling a urodynamics study
#'
#' A cohort with known truth, for fixtures, examples and reports. The public
#' repository must never carry patient data, so every demonstration in this
#' package runs on this.
#'
#' The generating model is deliberately not a plain additive one. It carries a
#' nonlinear age effect and one interaction, because a pipeline that is only
#' ever exercised on additive data will not reveal whether its spline and
#' hierarchy handling are right.
#'
#' The true coefficients are attached as the `truth` attribute, and the
#' intercept is solved numerically so the realised prevalence lands near
#' `prevalence` rather than wherever the other terms happen to put it.
#'
#' @param n Rows to generate.
#' @param prevalence Target outcome prevalence. The default, with the default
#'   `n`, gives roughly the 57 events the specification describes for the
#'   reference study, which is the regime where degrees of freedom have to be
#'   spent carefully.
#' @param years Calendar years to spread the cohort over, for temporal
#'   validation.
#' @param repeat_frac Fraction of rows that are a second visit by a patient
#'   already present, so clustered resampling has something to cluster.
#' @param seed Single whole number.
#'
#' @return A data frame of `n` rows with attribute `truth`, a list holding the
#'   true coefficients and the generating formula.
#'
#' @examples
#' cohort <- mm_synthetic_cohort(n = 200, seed = 1)
#' table(cohort$event)
#' attr(cohort, "truth")$coefficients
#' @export
mm_synthetic_cohort <- function(n = 500, prevalence = 0.11,
                                years = 2019:2024, repeat_frac = 0.08,
                                seed = 1978L) {
  if (length(n) != 1L || !is.numeric(n) || n < 20) {
    stop("`n` must be a single number of at least 20.", call. = FALSE)
  }
  if (length(prevalence) != 1L || !is.numeric(prevalence) ||
      prevalence <= 0 || prevalence >= 1) {
    stop("`prevalence` must be a single number strictly between 0 and 1.",
         call. = FALSE)
  }
  if (length(seed) != 1L || !is.numeric(seed) || seed != trunc(seed)) {
    stop("`seed` must be a single whole number.", call. = FALSE)
  }
  n <- as.integer(n)

  withr_seed <- function(code) {
    old <- if (exists(".Random.seed", envir = globalenv())) {
      get(".Random.seed", envir = globalenv())
    } else NULL
    set.seed(as.integer(seed))
    on.exit({
      if (is.null(old)) {
        suppressWarnings(rm(".Random.seed", envir = globalenv()))
      } else {
        assign(".Random.seed", old, envir = globalenv())
      }
    }, add = TRUE)
    code
  }

  withr_seed({
    cohort <- data.frame(
      age       = round(stats::rnorm(n, 62, 13), 1),
      bmi       = round(stats::rnorm(n, 29, 6), 1),
      sex       = factor(sample(c("female", "male"), n, TRUE,
                                prob = c(0.72, 0.28))),
      prior_uti = factor(sample(c("no", "yes"), n, TRUE,
                                prob = c(0.68, 0.32)),
                         levels = c("no", "yes")),
      indication = factor(sample(c("incontinence", "retention",
                                   "prolapse"), n, TRUE,
                                 prob = c(0.5, 0.3, 0.2))),
      year      = sample(years, n, TRUE),
      stringsAsFactors = FALSE
    )
    cohort$age <- pmin(pmax(cohort$age, 18), 95)
    cohort$bmi <- pmin(pmax(cohort$bmi, 15), 60)

    # Patient identifiers, with a minority of repeat visits.
    n_rep <- max(0L, as.integer(round(repeat_frac * n)))
    pid <- sprintf("p%04d", seq_len(n - n_rep))
    if (n_rep > 0L) pid <- c(pid, sample(pid, n_rep, replace = FALSE))
    cohort$pid <- sample(pid)

    # Truth. The age term is quadratic about 62 and the interaction is
    # prior_uti by sex, both prespecified in the fixture rather than
    # discovered from it.
    b <- c(age_sq        = 0.0011,
           bmi           = 0.045,
           sex_male      = 0.35,
           prior_uti_yes = 0.80,
           uti_by_male   = 0.60)

    structural <- b[["age_sq"]] * (cohort$age - 62)^2 +
      b[["bmi"]] * (cohort$bmi - 29) +
      b[["sex_male"]] * (cohort$sex == "male") +
      b[["prior_uti_yes"]] * (cohort$prior_uti == "yes") +
      b[["uti_by_male"]] * (cohort$prior_uti == "yes") *
        (cohort$sex == "male")

    # Solve the intercept so realised prevalence meets the target.
    gap <- function(a) mean(stats::plogis(a + structural)) - prevalence
    intercept <- stats::uniroot(gap, interval = c(-30, 30))$root

    cohort$event <- stats::rbinom(n, 1L,
                                  stats::plogis(intercept + structural))

    attr(cohort, "truth") <- list(
      coefficients = c(intercept = intercept, b),
      formula = paste("event ~ 0.0011*(age-62)^2 + 0.045*(bmi-29) +",
                      "0.35*male + 0.80*prior_uti +",
                      "0.60*prior_uti:male"),
      prevalence_target = prevalence
    )
    cohort
  })
}
