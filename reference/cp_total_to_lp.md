# Convert total points to the linear predictor

The printed linear predictor axis is affine in total points, so the line
through it is the exact mapping. Interpolating with clamped ends is not:
the axis need not be printed all the way down to zero points, and a
profile below its lowest tick would then be read as that tick. That is a
silent wrong answer, so the line is used and its linearity is checked
rather than trusted.

## Usage

``` r
cp_total_to_lp(nom, total)
```

## Arguments

- nom:

  An `rms` nomogram.

- total:

  Total points.

## Value

The linear predictor.
