# Which band a predicted risk falls in

The cut points are odds ratios against the reference, not multiples of
it. Multiples of a probability look natural and stop working as soon as
the outcome is common: twice a 62% match rate is not a probability, so
on the ENT applicant cohort every patient above the reference fell in
one band and the top two could not be reached at all. A logistic model
is linear in the log odds, so a band taken on the odds ratio is a band
on the scale the model works in, it is symmetric about the reference,
and it behaves the same at a 9% event rate as at a 62% one.

## Usage

``` r
mm_calculator_band(
  prob,
  threshold,
  higher_is = c("worse", "better"),
  subject = "patient",
  audience = c("clinician", "self"),
  event = "the outcome",
  n_predictors = NULL
)
```

## Arguments

- prob:

  A predicted probability.

- threshold:

  The risk the bands are relative to.

- higher_is:

  `"worse"` when a higher prediction is the bad outcome, `"better"` when
  it is the good one.

- subject:

  What one row is, in the singular.

## Value

A list: `level`, `color`, `odds_ratio` and `recommendation`. The band's
position is carried by the colour and by the sentence, not by a label of
its own: a pill reading WELL BELOW REFERENCE is a verdict printed larger
than the number it is about, and the sentence beneath it already says
the same thing in a form a reader can weigh.

## Details

The band is a position relative to the development cohort. Whether that
position is good or bad is not something the model knows, so `higher_is`
decides which end of the colour ramp it takes, and the label stays
directional either way.
