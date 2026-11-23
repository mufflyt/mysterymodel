# A hundred figures, of which the predicted number are marked

The frequency format, because a probability read as a percentage is
understood less reliably than the same quantity read as a count out of a
hundred. Rounding is to the nearest whole patient, which is what the
format can honestly carry.

## Usage

``` r
mm_calculator_icons(prob, band, subject = "patient", event = "had the outcome")
```

## Arguments

- prob:

  A predicted probability, possibly `NA`.

- band:

  The output of
  [`mm_calculator_band()`](https://mufflyt.github.io/mysterymodel/reference/mm_calculator_band.md),
  or `NULL`.

- subject:

  What one row is, in the singular.

- event:

  What the outcome is, in the past tense.

## Value

A Shiny tag.
