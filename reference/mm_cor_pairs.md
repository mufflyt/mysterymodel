# The strongly correlated numeric pairs, for a human to look at

Spearman, because clinical predictors are frequently skewed and Pearson
would be driven by the tail. Numeric columns only: a factor's
association with a number is what
[`mm_vif_check()`](https://mufflyt.github.io/mysterymodel/reference/mm_vif_check.md)
and
[`mm_redun_check()`](https://mufflyt.github.io/mysterymodel/reference/mm_redun_check.md)
cover.

## Usage

``` r
mm_cor_pairs(data, max = 0.5)
```

## Arguments

- data:

  Predictors only.

- max:

  Report pairs at or above this absolute correlation. Worth a human
  looking at rather than worth failing over, which is why nothing in
  this file treats it as a gate.

## Value

A data frame of `a`, `b`, `rho`, sorted by `abs(rho)` descending.
Possibly empty, which is the usual answer.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 250, seed = 5)
mm_cor_pairs(cohort[, c("age", "bmi")])
#> [1] a   b   rho
#> <0 rows> (or 0-length row.names)
```
