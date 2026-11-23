# Estimate a correction on each imputation and pool it

Scoring a sample by multiple imputation produces one linear predictor
per imputation per row, so there are several estimates of the correction
and they have to be combined. Getting the pooling wrong is invisible:
the point estimate is right either way and only the interval is too
narrow.

## Usage

``` r
mm_recal_mi(
  lp_mat,
  y,
  cluster = NULL,
  form = c("intercept", "two-parameter"),
  positive = NULL
)
```

## Arguments

- lp_mat:

  An `n` by `m` matrix of linear predictors, one column per imputation,
  rows in one consistent order.

- y:

  The outcome, length `n`, in that same row order.

- cluster:

  An identifier for rows that are not independent, or `NULL`.

- form:

  `"intercept"` for the constant alone, `"two-parameter"` for
  `a + b * lp`.

- positive:

  The level that means the event.

## Value

A list: `a`, `b`, `se_a`, `se_b`, `b_p`, `n`, `n_clusters`, `m`,
`fmi_a`, `fmi_b`, `per_imputation`, and a one-line `reason`.

## Details

This package fits on complete rows and has no imputation of its own, so
`lp_mat` comes from imputing elsewhere and scoring each completed data
set.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 300, seed = 9)
fit <- suppressWarnings(mm_model(
  mm_project("recal", "event", c("age", "bmi"),
             positive_class = 1, cohort = cohort), cohort))
lp <- as.numeric(fit$fit$linear.predictors)
# Two "imputations" standing in for a real set, to show the shape.
mm_recal_mi(cbind(lp, lp + 0.05), cohort$event, positive = 1)$a
#> [1] -0.025
```
