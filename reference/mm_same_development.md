# Refuse a cohort that is not the one the model was developed on

A row count cannot distinguish a cohort from a different cohort of the
same size, and every basis
[`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
reports describes the development sample. Scoring a different one and
calling the result apparent is not a smaller error than scoring none.

## Usage

``` r
mm_same_development(model, dev, what)
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- dev:

  The development rows a caller has re-derived.

- what:

  What the caller is about to do, for the message.

## Value

`TRUE`, invisibly, or an error.

## Details

The comparison is order sensitive, because the pairing of predictors to
outcome is what a c-statistic measures: the same rows in a different
order are the same sample, but nothing cheap tells that apart from the
same predictor rows carrying permuted outcomes, which is a different
sample entirely. So a reordered cohort is refused too, and the message
says so.
