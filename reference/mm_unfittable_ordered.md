# Whether an ordered factor is one rms can fit

[`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) accepts an ordered
factor whose level *labels* parse as numbers, and handles it the way
[`rms::scored()`](https://rdrr.io/pkg/rms/man/rms.trans.html) does: a
linear term in the scores plus a departure per level above the second,
so a four-level factor spends three degrees of freedom and its departure
from linearity is testable. It refuses one whose labels do not parse,
from inside `Design()`, with advice to change a global contrast option.

## Usage

``` r
mm_unfittable_ordered(column)
```

## Arguments

- column:

  A column of the cohort.

## Value

`TRUE` when the column is an ordered factor rms cannot fit.

## Details

[`levels()`](https://rdrr.io/r/base/levels.html) always returns
character, so asking whether the levels are numeric has to mean asking
whether they parse. An earlier version of this check asked
`is.numeric(levels(x))`, which is always `FALSE`, and so refused every
ordered factor including the ones rms fits perfectly well.
