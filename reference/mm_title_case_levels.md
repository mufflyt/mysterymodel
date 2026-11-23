# Title case the level text a categorical axis prints

Applied to the drawn copy, beside the axis renaming and for the same
reason: the verification reads the levels the fit holds, so a tidier
spelling must not reach it. What is printed and what was checked are
deliberately two objects here.

## Usage

``` r
mm_title_case_levels(nom)
```

## Arguments

- nom:

  An [`rms::nomogram()`](https://rdrr.io/pkg/rms/man/nomogram.html)
  object.

## Value

The nomogram, with printed level text title cased.

## Details

Only a main-effect axis whose values are text is touched. A continuous
axis carries numbers and an interaction axis is assembled from levels
that are already named elsewhere on the sheet.
