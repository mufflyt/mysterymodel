# Interaction blocks a nomogram cannot represent

A nomogram gives each predictor one axis and sums the points, so an
interaction only reaches the page as a separate axis per level of a
categorical partner. Two continuous predictors have no levels to
separate by, and
[`rms::nomogram()`](https://rdrr.io/pkg/rms/man/nomogram.html) says so
through its `interact` argument, which this package does not pass: the
resulting error names an argument the analyst never used and nothing
about what to do.

## Usage

``` r
mm_undrawable_blocks(model)
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

## Value

A character vector describing each undrawable block, empty when every
block can be drawn.

## Details

Checked before anything is drawn, so the refusal names the block rather
than arriving from inside rms.
