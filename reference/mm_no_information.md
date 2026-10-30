# The Brier score of predicting one constant risk for everyone

The denominator a scaled Brier, or skill score, is taken against.
Written once because the choice of *which* rate goes in is the whole
question: a column of scaled Briers each scaled by its own sample's
prevalence is a set of scores against different references, and a reader
compares down the column. The rate stays the caller's to supply for that
reason.

## Usage

``` r
mm_no_information(rate)
```

## Arguments

- rate:

  An event rate.

## Value

The no-information Brier.
