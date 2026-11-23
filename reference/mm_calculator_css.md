# The calculator's stylesheet

One string rather than a file under `inst/`, so that the application is
a value a caller can hand around and the package has no static assets to
keep in step with the code that references them.

## Usage

``` r
mm_calculator_css()
```

## Value

A single character string of CSS.
