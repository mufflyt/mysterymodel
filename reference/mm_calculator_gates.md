# Which inputs are switched off by another input, and at what value

Some predictors only mean something when another one says so. A Step 2
score has no value for an applicant who has not sat Step 2, and a form
that lets a reader say "not reported" and leave 250 in the box beside it
is offering a combination the model was never fitted on: the model reads
that as an applicant with the parked score plus the not-reported offset,
which is not what the reader typed and not what they meant.

## Usage

``` r
mm_calculator_gates(gates, model)
```

## Arguments

- gates:

  A named list, or `NULL`. Each name is a gated predictor and each
  element is a list with `by`, `when`, and optionally `value`.

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

## Value

The gates, normalised, with `value` and the controlling predictor's
printed name filled in.

## Details

So a gate names the controlling predictor, the level at which the gate
closes, and the value the gated input takes while it is shut. The
default value is the median the `datadist` recorded, which is where a
parked value is usually put.
