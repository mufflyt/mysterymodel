# One profile per selected value of every predictor

One predictor moves at a time while the others sit at their first
tabulated value, so every value `pick` selects is exercised without
taking the product of them all. Both callers build this shape and differ
only in which values they visit, which is why the construction is here:
the on-tick agreement and the between-tick reading error are compared
with each other, and that comparison assumes one shape.

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
