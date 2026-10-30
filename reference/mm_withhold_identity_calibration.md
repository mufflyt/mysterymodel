# Withhold a calibration that is an identity rather than an estimate

Scoring an unpenalized maximum-likelihood fit on the very rows that
produced it forces the calibration intercept to zero and the slope to
one: they are the fit's own score equations rearranged, not evidence
about calibration. Printed in a column beside a held-out slope they read
as the model being perfectly calibrated, which is the one thing they
cannot show.

## Usage

``` r
mm_withhold_identity_calibration(row, tol = 1e-06)
```

## Arguments

- row:

  A one-row metrics frame from
  [`mm_metrics()`](https://mufflyt.github.io/mysterymodel/reference/mm_metrics.md).

- tol:

  How close to 0 and 1 counts as the identity.

## Value

The row, with the calibration withheld and the reason appended when it
is an identity.

## Details

The identity is detected rather than assumed, so a fitting method that
does not force it, a penalized fit for instance, has its apparent
calibration reported as the estimate it would then be.
