# How large a sheet this nomogram needs

A nomogram is a stack of rows and a row does not get shorter when there
are more of them. A fixed page therefore degrades with the size of the
model, and it degrades silently: the sheet is still drawn, still
verified, and still wrong to hand to anyone, because the long value
labels of adjacent rows overprint each other. Height is set from the row
count instead, with the old default as the floor so a small model is
unchanged.

## Usage

``` r
mm_nomogram_page(nom, width = NULL, height = NULL)
```

## Arguments

- nom:

  An [`rms::nomogram()`](https://rdrr.io/pkg/rms/man/nomogram.html)
  object, after any relabelling.

- width, height:

  Inches, or `NULL` to size to the model.

## Value

A list with `width` and `height`.

## Details

Rows are every axis the sheet carries, which is one per predictor plus
the points scale, the total points scale, the linear predictor and the
risk axis, and the header row above them.
