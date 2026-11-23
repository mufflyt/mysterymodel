# Which variables are predictable from the others

Wraps [`Hmisc::redun()`](https://rdrr.io/pkg/Hmisc/man/redun.html),
which drops variables one at a time, so its output is a SEQUENCE and not
a set: the second entry is redundant given the first was already
dropped. Reporting it as a set would invite dropping both.

## Usage

``` r
mm_redun_check(data, r2 = 0.9)
```

## Arguments

- data:

  Predictors only, with the outcome already removed.

- r2:

  The cutoff above which a variable counts as redundant.
  [`Hmisc::redun()`](https://rdrr.io/pkg/Hmisc/man/redun.html)'s own
  default, and the conventional one: a variable 90% predictable from the
  others carries almost nothing of its own.

## Value

A list with `r2_each`, the ordered `dropped` sequence, `ok`, and a
one-line `reason`.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 250, seed = 5)
mm_redun_check(cohort[, c("age", "bmi")])$reason
#> [1] "redundancy: none at R2 >= 0.9; highest is age at 0.000"
```
