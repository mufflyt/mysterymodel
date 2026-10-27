# Predict risk from exactly the fitted model

Checks the incoming rows against the schema recorded at fit time, then
predicts on the response scale from the stored `rms` fit.

## Usage

``` r
cp_predict(model, newdata, on_missing = c("stop", "na"))
```

## Arguments

- model:

  A
  [`cp_model()`](https://mufflyt.github.io/mysterymodel/reference/cp_model.md).

- newdata:

  Rows to score. Required: a model carries no copy of the cohort, both
  because the specification asks that patient-level originals not be
  retained and because a stored copy is one that can drift from the data
  the caller actually has.

- on_missing:

  One of `"stop"` or `"na"`. Rows with a missing predictor cannot be
  scored by a complete-data model; `"stop"` refuses them and `"na"`
  returns `NA` for those rows.

## Value

A data frame with one row per input row: `.pred` on the probability
scale, and `.extrapolated` marking rows outside the development range.

## Details

The checks are the reason this is not a thin wrapper around
[`stats::predict()`](https://rdrr.io/r/stats/predict.html). A factor
level the model never saw cannot be scored, and `rms` signals that a
long way from its cause, so an unseen level is refused here by name. A
value outside the range the model was developed on can be scored, and
is, but it is extrapolation and the result says so rather than looking
like any other row.

easystats is not used for this. `insight::get_predicted()` returns NULL
for an `lrm` fit, so there is no prediction path through that ecosystem.
See `inst/capability-matrix.md`.

## Examples

``` r
cohort <- cp_synthetic_cohort(n = 300, seed = 1)
project <- cp_project("uds", "event", c("age", "bmi", "sex"),
                      cohort = cohort)
fit <- cp_model(project, cohort, nonlinear = "age")
head(cp_predict(fit, cohort[1:5, ]))
#>        .pred .extrapolated
#> 1 0.10013810         FALSE
#> 2 0.08130734         FALSE
#> 3 0.12202587         FALSE
#> 4 0.10521724         FALSE
#> 5 0.09260464         FALSE
```
