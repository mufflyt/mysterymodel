# Describe the cohort, with denominators and missingness

A Table 1 in tidy form: one row per variable level or statistic, overall
and by outcome, with the denominator each percentage is taken over and
the missing count beside it.

## Usage

``` r
cp_eda(cohort, by = NULL, vars = NULL, digits = 1)
```

## Arguments

- cohort:

  A data frame, or a
  [`cp_clean()`](https://mufflyt.github.io/mysterymodel/reference/cp_clean.md)
  result.

- by:

  Optional column to stratify by, typically the outcome.

- vars:

  Columns to describe. Defaults to all but `by`.

- digits:

  Decimal places for continuous summaries.

## Value

An object of class `cp_eda`, holding `table` and `missing`.

## Details

Missingness travels with the description rather than in a separate
table, because a percentage whose denominator excludes missing rows
reads as a fact about the cohort when it is a fact about the rows that
happened to be complete.

Formatting follows the specification: counts with thousands separators,
percentages to one decimal, means with standard deviations, medians with
the quartiles.

No dependency on a table-rendering package. This returns a data frame,
so `gt`, `gtsummary`,
[`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html) or Quarto
can render it, and none of them is needed to compute it.

## Examples

``` r
cohort <- cp_synthetic_cohort(n = 300, seed = 1)
cp_eda(cohort, by = "event", vars = c("age", "bmi", "sex"))
#> <cp_eda>  300 rows, by event
#>       variable         statistic           Overall         event = 0
#>  (denominator)                 n               300               272
#>            age         mean (SD)       62.4 (12.5)       62.4 (12.4)
#>            age median (p25, p75) 61.5 (54.3, 70.8) 61.5 (54.3, 70.8)
#>            age    missing, n (%)          0 (0.0%)          0 (0.0%)
#>            bmi         mean (SD)        29.0 (6.2)        28.9 (6.1)
#>            bmi median (p25, p75) 28.8 (24.8, 33.1) 28.7 (24.8, 32.9)
#>            bmi    missing, n (%)          0 (0.0%)          0 (0.0%)
#>            sex     female, n (%)       221 (73.7%)       201 (73.9%)
#>            sex       male, n (%)        79 (26.3%)        71 (26.1%)
#>            sex    missing, n (%)          0 (0.0%)          0 (0.0%)
#>          event = 1
#>                 28
#>        62.8 (14.0)
#>  61.1 (55.8, 70.0)
#>           0 (0.0%)
#>         29.5 (7.5)
#>  29.1 (25.5, 35.5)
#>           0 (0.0%)
#>         20 (71.4%)
#>          8 (28.6%)
#>           0 (0.0%)
```
