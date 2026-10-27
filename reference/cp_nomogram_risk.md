# Read one profile off the nomogram, as a clinician would

Sums the points from each axis that applies to the profile, then
interpolates the total on the printed linear predictor axis. No model
object is consulted, which is what makes this a check rather than a
restatement of the fit.

## Usage

``` r
cp_nomogram_risk(nom, profile)
```

## Arguments

- nom:

  An `rms` nomogram.

- profile:

  One row.

## Value

Predicted risk, or `NA_real_` if no axis applies.

## Details

An axis applies only when the profile matches every categorical value
the axis holds fixed. That is how the mutually exclusive axes an
interaction produces are handled: exactly one of them applies, so no
variable is counted twice and none is missed.
