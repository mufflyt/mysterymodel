# The risk the calculator's bands are taken relative to

A fitted model carries exactly one threshold that means anything without
a further analysis, which is the rate at which the outcome occurred in
the cohort it was developed on. A decision threshold is a different
object: it comes from a decision curve and the clinical cost of each
error, neither of which this package has. So the default is the
development prevalence and the screen names it, rather than a round
number that would look like a standard.

## Usage

``` r
mm_calculator_threshold(model, threshold = NULL)
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- threshold:

  A supplied threshold, or `NULL`.

## Value

A single probability.
