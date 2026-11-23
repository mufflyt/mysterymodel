# Fit the two-parameter correction, a + b \* lp

`b` below 1 says the predictions are too spread out as well as too high.
Clustered the same way as
[`mm_recal_intercept()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_intercept.md),
and `b` is the parameter that needs it, because whether `b` differs from
1 is the question that decides between this form and the constant alone.

## Usage

``` r
mm_recal_slope(lp, y, cluster = NULL, positive = NULL)
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

A list: `a`, `b`, `se_a`, `se_b`, `b_z`, `b_p`, `n`, `events`,
`cluster_robust`, `n_clusters`, and a one-line `reason`.

## Details

The test on `b` is against 1, not against 0. A slope correction of 1 is
no correction, so the null that matters is `b = 1`; testing `b = 0`
would ask whether the model discriminates at all, which is a different
question and one
[`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
already answers.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 400, seed = 9)
fit <- suppressWarnings(mm_model(
  mm_project("recal", "event", c("age", "bmi"),
             positive_class = 1, cohort = cohort), cohort))
lp <- as.numeric(fit$fit$linear.predictors)
mm_recal_slope(lp, cohort$event, positive = 1)$b
#> [1] 1
```
