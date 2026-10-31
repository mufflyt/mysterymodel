# Support and separation for one candidate, reported and never decisive

Sparse is not the same as unidentifiable, and this function exists to
keep them apart. A cell carrying twelve rows and no events leaves the
design matrix at full rank: the interaction is estimable, the likelihood
is close to flat in that direction, and the test returns a statistic
near zero with a p-value near one. That is worth saying out loud beside
the p-value, and it is not grounds for refusing to report the test,
because the same shape arises in a cohort where the interaction is
simply small.

## Usage

``` r
mm_interaction_support(frame, pair, y)
```

## Arguments

- frame:

  The development rows.

- pair:

  The two predictor names.

- y:

  The 0/1 outcome for those rows.

## Value

A list of counts and flags, with `note` describing anything found.

## Details

Only
[`mm_interaction_rank()`](https://mufflyt.github.io/mysterymodel/reference/mm_interaction_rank.md)
decides whether a test is reported.
