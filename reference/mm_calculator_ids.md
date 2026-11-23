# Positional input identifiers for the calculator

A predictor may be named anything a data frame permits, and a Shiny
input identifier may not, so the identifiers are positional and both
halves of the application derive them the same way.

## Usage

``` r
mm_calculator_ids(specs)
```

## Arguments

- specs:

  The `predictors` element of a prediction schema.

## Value

A character vector of identifiers, named by predictor.
