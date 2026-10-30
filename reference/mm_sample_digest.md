# A fingerprint of the rows an analysis was run on

Factors are hashed as their values and not as their level sets, because
[`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
drops a level no fitted row carries and a caller re-deriving the same
frame has not. Numeric columns are hashed as they are, so nothing is
rounded on the way in.

## Usage

``` r
mm_sample_digest(project, frame)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- frame:

  The rows.

## Value

A SHA-256 string. Not a copy of the data, and not invertible.
