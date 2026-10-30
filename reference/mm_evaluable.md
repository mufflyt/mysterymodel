# Which rows a complete-data model can be fitted to, or scored and counted on

One rule, read by fitting and by both kinds of validation, so that the
sample a model was estimated on and the sample it is judged against
cannot be decided twice and differently. The breakdown is part of the
return value rather than a side effect, because the exclusions belong in
the report.

## Usage

``` r
mm_evaluable(project, frame, require_outcome = TRUE)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- frame:

  Rows to assess.

- require_outcome:

  Whether the outcome must be observed. `TRUE` for fitting and for
  scoring that will be turned into a metric; `FALSE` when only a
  prediction is wanted.

## Value

A list: `usable` and `predictable` masks, the counts `n_total`,
`n_scored`, `n_excluded`, `missing_predictor`, `missing_outcome`,
`missing_both`, and `by_variable`.

## Details

A missing predictor and a missing outcome are counted apart, and the
overlap separately. They are different exclusions: one is a patient who
cannot be scored, the other a patient who can be scored but contributes
nothing to a performance estimate. Neither is an event, and treating a
missing outcome as a non-event is the specific error this separation
exists to prevent.

This is complete-case analysis, which is a computational strategy and
not a guarantee. Missingness may be informative, the more so in the
small clinical cohorts this package is for, so the counts are reported
everywhere they apply rather than summarised away. Multiple imputation
is the answer and is not in this package yet.
