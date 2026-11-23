# Apply a correction to linear predictors

`b = 1` is the intercept-only form. Returns probabilities, which is what
a nomogram's bottom axis and a calculator's figure both show.

## Usage

``` r
mm_recal_apply(lp, a, b = 1)
```

## Arguments

- lp:

  Linear predictors from the frozen model.

- a:

  The intercept correction.

- b:

  The slope correction. 1 leaves the spread alone.

## Value

Corrected probabilities, one per element of `lp`.

## Examples

``` r
mm_recal_apply(c(-1, 0, 1), a = 0.6)
#> [1] 0.4013123 0.6456563 0.8320184
mm_recal_apply(c(-1, 0, 1), a = 0.6, b = 0.8)
#> [1] 0.4501660 0.6456563 0.8021839
```
