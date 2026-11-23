# What the band means, for someone scoring another person

The odds ratio is here because a clinician reading a model's output can
use it and because it is the quantity the band was cut on. It is the
wrong thing to put in front of the person the prediction is about.

## Usage

``` r
mm_band_text_clinician(prob, threshold, or, level, subject)
```

## Arguments

- prob, threshold:

  Probabilities.

- or:

  The odds ratio against the reference.

- level:

  The band.

- subject:

  What one row is, in the singular.

## Value

A single string.
