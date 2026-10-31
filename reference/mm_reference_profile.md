# The profile the spline panels hold everything else at

Median for a continuous predictor and the most common level for a
categorical one, which is a defensible place to stand and not the only
one. It is returned with the curves because an adjusted curve means
nothing without the values it was adjusted to.

## Usage

``` r
mm_reference_profile(project, frame, at = NULL)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- frame:

  The development rows.

- at:

  Optional override, a named list or one-row data frame.

## Value

A one-row data frame carrying every predictor.
