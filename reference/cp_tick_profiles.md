# One profile per tabulated tick of every predictor

Each predictor is varied over its ticks while the others sit at their
first, so every tick of every axis is exercised without taking the
product of them all.

## Usage

``` r
cp_tick_profiles(nom, model)
```

## Arguments

- nom:

  An `rms` nomogram.

- model:

  A
  [`cp_model()`](https://mufflyt.github.io/mysterymodel/reference/cp_model.md).

## Value

A data frame of profiles.
