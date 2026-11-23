# Optimism of the whole modelling strategy, not just of the coefficients

Refits the entire strategy inside every bootstrap resample and scores
each refit on the development rows, so the optimism being corrected
includes every data-dependent choice the strategy makes.

## Usage

``` r
mm_full_process(
  model,
  cohort,
  B = 200L,
  min_valid = mm_min_resamples(B),
  refit = NULL
)
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

- refit:

  `NULL`, or a `function(project, draw)` returning an
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  fitted on `draw`. Supply it when the strategy makes a data-dependent
  choice this function cannot see - a selection step, tuning, an
  imputation - so the choice is re-made inside every resample and its
  optimism is in the correction. It is called once on the development
  rows first, and must give the same equation as `model`.

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

What it re-executes on its own is knot placement, `datadist` and factor
levels. Anything else the strategy learns from the data - which
predictors are splined, which interactions are in the model, a selection
step, tuning, imputation - is the caller's, and `refit` is how the
caller puts it inside the resampling. Without `refit` those choices are
inherited from `model` and the optimism excludes them, which
`held_fixed` says and the note repeats.

THE CLAIM IS COMPUTED, NOT WRITTEN DOWN. `covers` and `held_fixed` are
built from what actually happened in this call. An earlier version
stated "imputation, selection and tuning are not in this pipeline yet"
as a string literal, which stopped being true the moment
[`mm_splines()`](https://mufflyt.github.io/mysterymodel/reference/mm_splines.md)
and
[`mm_interactions()`](https://mufflyt.github.io/mysterymodel/reference/mm_interactions.md)
shipped: a caller who screens, picks and then validates was told the
thing it most needed to doubt, and the test suite asserted the sentence.

`refit` is checked against `model` before any resample is drawn. It is
called once on the development rows, and the equation it produces must
be the equation being corrected - otherwise the optimism belongs to a
model nobody fitted, which is the failure that makes a wrong number look
like a careful one.

Resamples that cannot be fitted are counted rather than dropped quietly.
A resample missing a factor level, or separating, is a real feature of
small cohorts, and an optimism averaged over the survivors of a
selection nobody reported is not the quantity it claims to be.
