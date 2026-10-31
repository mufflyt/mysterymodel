# The rank of a design matrix, scaled so units cannot decide it

From the singular values with a relative tolerance, rather than from
[`qr()`](https://rdrr.io/r/base/qr.html), because a column measured in
years and one in kilograms differ by orders of magnitude and the pivoted
decomposition's default tolerance then answers a question about scaling
rather than about rank.

## Usage

``` r
mm_matrix_rank(x, tol = 1e-07)
```

## Arguments

- x:

  A design matrix.

- tol:

  Relative tolerance on the singular values.

## Value

The rank.
