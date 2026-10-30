# The tabulated values each predictor has on the nomogram

An axis may carry more than one variable. An interaction makes `rms`
emit mutually exclusive axes such as `sex (prior_uti=no)` and
`sex (prior_uti=yes)`, each holding both variables, so a predictor's
ticks have to be gathered across axes rather than read off one.

## Usage

``` r
mm_axis_values(nom, predictors)
```

## Arguments

- nom:

  An `rms` nomogram.

- predictors:

  Model predictors.

## Value

Named list of tabulated values.
