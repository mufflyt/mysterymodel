# Put printed names on the drawn axes

Applied to a copy at draw time. The verification above matches axes to
predictors by the names `rms` gave them, so relabelling before the check
would mean checking a different object from the one that was reasoned
about.

## Usage

``` r
mm_relabel_axes(nom, labels)
```

## Arguments

- nom:

  An [`rms::nomogram()`](https://rdrr.io/pkg/rms/man/nomogram.html)
  object.

- labels:

  A named character vector, or `NULL`.

## Value

The nomogram, with the named axes renamed.
