# The parameters a declared model would spend, counted before it is fitted

A categorical predictor spends one parameter per level after the first,
a continuous one spends one, a spline spends `knots - 1`, and an
interaction spends the product of what its two sides spend. Counting it
beforehand is what makes it possible to refuse a model that cannot be
estimated instead of waiting for
[`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) to grind through a
design matrix wider than the cohort is long.

## Usage

``` r
mm_parameter_budget(
  project,
  frame,
  nonlinear = NULL,
  knots = 4L,
  pairs = list()
)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- frame:

  The rows that would be fitted.

- nonlinear, knots, pairs:

  The shape, as
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  resolved it.

## Value

A list with `total` and the per-predictor `spent`.

## Details

The case this exists for is an identifier offered as a predictor. A
column with one level per row spends `n - 1` parameters, saturates the
model on its own, and takes a long time to fail. The rule here is exact
rather than a threshold: a model whose parameters reach the number of
rows has nothing left to estimate them with.
