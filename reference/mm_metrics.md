# Discrimination, calibration and accuracy for one set of predictions

Discrimination, calibration and accuracy for one set of predictions

## Usage

``` r
mm_metrics(p, y, basis, note = "", reference = NULL)
```

## Arguments

- p:

  Predicted probabilities.

- y:

  0/1 outcome.

- basis:

  Label for the row.

- note:

  What produced it.

- reference:

  The no-information Brier to scale against, that is the Brier of a
  model predicting one constant risk. `NULL` uses the scored sample's
  own prevalence, which is the conventional within-sample skill score
  and is not comparable across samples of different prevalence.
  [`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
  passes the development cohort's reference to every basis so that one
  column means one thing.

## Value

A one-row data frame.
