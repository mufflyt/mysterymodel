# Fit an intercept correction on a recalibration sample

Fits `y ~ offset(lp)`, so the model's linear predictor is held fixed and
the constant is the only free parameter. A positive value means the
model predicts too low.

## Usage

``` r
mm_recal_intercept(lp, y, cluster = NULL, positive = NULL)
```

## Arguments

- lp:

  Linear predictors from the FROZEN model, not refitted here. For an
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  these are `fitted(model, scale = "link")` on new rows.

- y:

  The observed outcome, in any form
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  accepts.

- cluster:

  An identifier for rows that are not independent, or `NULL`.

- positive:

  The level that means the event, as in
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

## Value

A list: `a`, `se`, `n`, `events`, `cluster_robust`, `n_clusters`, and a
one-line `reason`.

## Details

The standard error is cluster-robust when `cluster` is supplied and the
`sandwich` package is installed. When one patient contributes more than
one row, a model-based standard error treats those rows as independent
and is too small; the returned `cluster_robust` flag says which was
used, rather than leaving a caller to assume.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 400, seed = 9)
fit <- suppressWarnings(mm_model(
  mm_project("recal", "event", c("age", "bmi"),
             positive_class = 1, cohort = cohort), cohort))
lp <- as.numeric(fit$fit$linear.predictors)
mm_recal_intercept(lp, cohort$event, positive = 1)$reason
#> [1] "intercept correction +0.0000 (SE 0.1680, model-based, rows treated as independent) from 400 rows, 40 event(s) (10.0%)"
```
