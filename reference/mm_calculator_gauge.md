# The gauge needle, pointed at the predicted risk

The dial runs from zero to four times the threshold rather than to 1,
because a needle that has to render every clinically distinct value of a
low-prevalence outcome inside the first few degrees of a 0 to 100% sweep
shows nothing. Both ends are printed under the dial, so the sweep cannot
be mistaken for a percentage scale.

## Usage

``` r
mm_calculator_gauge(prob, band, threshold, higher_is = c("worse", "better"))
```

## Arguments

- prob:

  A predicted probability, possibly `NA`.

- band:

  The output of
  [`mm_calculator_band()`](https://mufflyt.github.io/mysterymodel/reference/mm_calculator_band.md),
  or `NULL`.

- threshold:

  The risk the bands are relative to.

## Value

A Shiny tag.
