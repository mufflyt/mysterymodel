# How far an off-tick reading can be from the model

Reported so the axis's own resolution is a stated number rather than an
unexamined assumption. Evaluated midway between ticks, the worst case
for linear interpolation across a curve.

## Usage

``` r
mm_reading_error(nom, model)
```

## Arguments

- nom:

  An `rms` nomogram.

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

## Value

Largest absolute risk difference found between ticks.
