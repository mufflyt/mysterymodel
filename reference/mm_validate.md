# Validate the model, on a stated basis

Returns one row per basis, because the three numbers a clinical
prediction paper reports are not interchangeable and presenting one as
another is the commonest way a published model flatters itself.

## Usage

``` r
mm_validate(model, cohort, B = 200L, full_process = FALSE)
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- cohort:

  The cohort, for held-out scoring and the split. Its development rows
  must be the ones the model was fitted on.

- B:

  Bootstrap resamples.

- full_process:

  Also run the full-process bootstrap. Off by default because it refits
  `B` times and costs accordingly.

## Value

An object of class `mm_validation`: a data frame of metrics by basis,
plus what produced them.

## Details

The bases are:

- **apparent**, the model scored on the rows it was fitted to. Always
  optimistic, reported so that the optimism is visible. Its calibration
  is withheld rather than printed: scoring an unpenalized fit on its own
  rows forces the intercept to zero and the slope to one, so those two
  numbers describe the estimator and not the model.

- **bootstrap, fixed model**, from
  [`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html). Each
  resample refits the *same formula*, which corrects the optimism of
  estimating coefficients. It does **not** repeat imputation, selection,
  tuning or interaction screening, so it is not validation of a
  modelling strategy that includes those steps. The specification
  requires that distinction be made rather than assumed, and this column
  is where it is made. It does draw whole clusters when the project
  declares one, by passing `cluster` through to
  [`rms::predab.resample()`](https://rdrr.io/pkg/rms/man/predab.resample.html),
  and it reports how many resamples actually fitted, because rms keeps
  only those and says so only when asked.

- **held out**, rows the project's split reserved. Scored once.

- **bootstrap, full process**, with `full_process = TRUE`. Refits the
  whole strategy inside every resample, so the optimism corrected
  includes the data-dependent choices the fixed-model bootstrap
  inherits. See
  [`mm_full_process()`](https://mufflyt.github.io/mysterymodel/reference/mm_full_process.md)
  for what it does and does not re-execute.

## Incomplete rows

Every basis is judged on the rows that can be judged, and the exclusions
are reported rather than absorbed.
[`mm_evaluable()`](https://mufflyt.github.io/mysterymodel/reference/mm_evaluable.md)
is the one rule, the same one
[`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
fitted under, so the sample a model is measured against is the sample it
was estimated on; validating against a cohort whose development rows do
not match the fit is an error rather than a quietly different number.
The bootstraps resample the fitted cohort, never the supplied frame.

A missing predictor and a missing outcome are counted apart, with the
overlap separately, because they are different exclusions and because
taking a missing outcome for a non-event leaves the event count
unchanged while inflating the denominator.

Rows are selected first and
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
is then called at its own default of `on_missing = "stop"`, so the
complete-case path is explicit here and prediction keeps refusing to put
a number on an incomplete record.

This is complete-case analysis. It is a computational strategy and not a
guarantee: the estimates assume the exclusions are uninformative, which
is an assumption rather than a finding, and the `note` column says so
whenever any row was excluded. Multiple imputation is not in this
package yet.

## The scaled Brier column

Every basis is scaled against one reference, the Brier of a model
predicting the development cohort's prevalence for everyone, reported as
`brier_ref`. Scaling each basis by its own prevalence is the
conventional within-sample skill score, and a column of those is a set
of scores against different references, which is a comparison a reader
will make down the column and should not. Where a basis has a prevalence
of its own, the `note` gives the value its own reference would produce.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 300, seed = 1)
project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                      cohort = cohort, split_var = "year",
                      split_at = 2023)
fit <- mm_model(project, cohort, nonlinear = "age")
#> Warning: the development sample may be too small for this model: 190 rows is 1928 short of the 2118 a model of 5 parameter(s) needs at 8.4% prevalence for 90% shrinkage. Coefficients from a sample this size are expected to be overfitted; see the adequacy element of the returned object.
mm_validate(fit, cohort, B = 25)
#> <mm_validation>  full-process: FALSE
#>   apparent                 n=190   events=16   C=0.6257 (0.4652-0.7862)
#>   bootstrap, fixed model   n=190   events=16   C=0.5010  slope=0.3818
#>   held out                 n=110   events=12   C=0.3844 (0.2074-0.5613)  slope=-1.1131
#>   Fixed-model bootstrap only. Not validation of a strategy.
```
