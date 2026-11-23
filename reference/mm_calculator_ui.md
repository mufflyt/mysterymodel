# The calculator's inputs, read from the prediction schema

Separate from
[`mm_calculator()`](https://mufflyt.github.io/mysterymodel/reference/mm_calculator.md)
so that what a clinician is offered can be checked without a browser: a
dropdown must contain the levels the model was developed on and no
others.

## Usage

``` r
mm_calculator_ui(
  model,
  title = NULL,
  subtitle = NULL,
  threshold = NULL,
  subject = "patient",
  drawn = NULL,
  audience = c("clinician", "self"),
  gates = list()
)
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- title:

  The heading, or `NULL` for the default.

- subtitle:

  The line under it, or `NULL` for the default.

- threshold:

  The risk the bands are relative to.

- subject:

  What one row is, in the singular.

- drawn:

  The output of
  [`mm_calculator_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_calculator_nomogram.md),
  or `NULL`.

- audience:

  Who the page is written for.

- gates:

  Inputs another input switches off, already normalised by
  [`mm_calculator_gates()`](https://mufflyt.github.io/mysterymodel/reference/mm_calculator_gates.md).

## Value

A Shiny UI definition.
