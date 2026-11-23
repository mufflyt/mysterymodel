# Draw the model's nomogram for the page, or say why there is none

Drawn once when the application is built, not per session, because the
sheet is a property of the fitted model and nothing on the page changes
it. The figure is served from a temporary directory rather than
embedded, so a large nomogram does not inflate every page load.

## Usage

``` r
mm_calculator_nomogram(model, higher_is = "worse")
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- higher_is:

  Whether a higher prediction is the worse outcome.

## Value

A list with `src` and `nom` when the model could be drawn, or `refusal`
when it could not. `NULL` when the drawing device is absent.

## Details

The drawing goes through
[`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md),
which refuses to return a sheet that disagrees with
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
when read back. That refusal is the reason the nomogram can be shown
beside the calculator at all: the two would otherwise be two instruments
that merely look like each other.
