# Generalized variance inflation factors per variable

Fox and Monette's generalized variance inflation factor, computed from
the correlation matrix of the coefficient estimates:
`GVIF = det(R_jj) * det(R_-j-j) / det(R)`. For a one-parameter term it
equals the ordinary variance inflation factor. `vif_scale` is
`GVIF^(1/df)`, which puts a multi-parameter term back on the scale a
reader compares against 4.

## Usage

``` r
mm_gvif(fit)
```

## Arguments

- fit:

  An `rms` fit carrying an `assign` list.

## Value

A data frame of `variable`, `df`, `gvif`, `adjusted` and `vif_scale`, or
`NULL` when the grouping is unavailable.
