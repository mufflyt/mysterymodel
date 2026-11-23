# Combine one scalar estimate across imputations by Rubin's rules

Averaging the estimates alone reports the within-imputation standard
error as the whole of the uncertainty and hides the between-imputation
variance, so an interval on a deployment constant would be too narrow
precisely because the missing data had been handled properly. Rubin's
rules carry that variance.

## Usage

``` r
mm_rubin(est, se)
```

## Arguments

- est:

  Per-imputation point estimates.

- se:

  Per-imputation standard errors, the same length.

## Value

A list: `est`, `se`, `m`, `m_dropped`, `within`, `between`, `fmi`, `df`,
and a one-line `reason`. Imputations whose estimate or standard error is
not finite are dropped AND counted, because one imputation that failed
to converge must not silently become a missing contribution to the
between-imputation variance.

## Details

Not a general-purpose pooler: it combines one scalar estimate and its
standard error, which is what
[`mm_recal_intercept()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_intercept.md)
and
[`mm_recal_slope()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_slope.md)
return. Anything with a covariance between parameters needs a full
pooling implementation.

## Examples

``` r
mm_rubin(c(0.61, 0.58, 0.64), c(0.11, 0.12, 0.11))$reason
#> [1] "+0.6100 (SE 0.1186) pooled over 3 imputation(s) by Rubin's rules; within 0.01287, between 0.00090, FMI 0.085"
```
