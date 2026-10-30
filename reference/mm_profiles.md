# One profile per selected value of every predictor

One predictor moves at a time while the others sit at their first
tabulated value, so every value `pick` selects is exercised without
taking the product of them all. Both callers want that shape and differ
only in which values they visit, so the construction is here and the
choice is theirs: a profile built one way for the on-tick agreement
check and another for the between- tick reading error would be two
shapes, and the comparison between those two numbers assumes one.

## Usage

``` r
mm_profiles(vals, pick, schema)
```

## Arguments

- vals:

  Tabulated values per predictor, from
  [`mm_axis_values()`](https://mufflyt.github.io/mysterymodel/reference/mm_axis_values.md).

- pick:

  Given one predictor's values, the values to visit. Length zero skips
  that predictor.

- schema:

  The model's prediction schema, whose factor levels the profiles are
  given back before they are returned.

## Value

A data frame of profiles, or `NULL` when `pick` selected nothing.
