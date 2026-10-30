# Optimism of the whole modelling strategy, not just of the coefficients

Refits the entire strategy inside every bootstrap resample and scores
each refit on the development rows, so the optimism being corrected
includes every data-dependent choice the strategy makes.

## Usage

``` r
mm_full_process(model, cohort, B = 200L, min_valid = mm_min_resamples(B))
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- cohort:

  The cohort.

- B:

  Resamples, checked by
  [`mm_check_resamples()`](https://mufflyt.github.io/mysterymodel/reference/mm_check_resamples.md)
  before anything is drawn.

- min_valid:

  Fewest successful resamples for the result to be reported as adequate.

## Value

A list with the optimism, the corrected metrics and the count of valid
resamples.

## Details

This is the distinction the specification insists on.
[`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html) refits
one fixed formula, which corrects the optimism of estimating
coefficients. It does not re-derive anything the formula was chosen or
shaped by. Here the resample gets its own spline knot placement, its own
`datadist`, and its own factor-level handling, because all three are
learned from data and all three are part of what would be redone on a
new sample.

What this does **not** yet re-execute, because the package does not do
them yet, is imputation, feature selection, tuning and interaction
screening. A strategy including any of those is not fully validated by
this function either, and `covers` names what was actually repeated so
the claim stays honest as the pipeline grows.

Resamples that cannot be fitted are counted rather than dropped quietly.
A resample missing a factor level, or separating, is a real feature of
small cohorts, and an optimism averaged over the survivors of a
selection nobody reported is not the quantity it claims to be.
