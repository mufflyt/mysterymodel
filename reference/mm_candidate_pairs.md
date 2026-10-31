# Candidate interaction pairs, checked before anything is fitted

Strong hierarchy is checked by
[`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
when it builds a formula. This checks the things a formula cannot: that
a pair is a pair, that it is not a predictor with itself, and that the
same block has not been asked for twice under two spellings. An
interaction's identity is the unordered pair, so `c("age", "sex")` and
`c("sex", "age")` are the same candidate.

## Usage

``` r
mm_candidate_pairs(project, candidates)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- candidates:

  List of length-two character vectors.

## Value

The candidates, each with a `label` and the unordered `key` used to
compare them.
