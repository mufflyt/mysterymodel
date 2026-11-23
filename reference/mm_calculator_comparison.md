# The rows a reader has kept, side by side

Taken from `DynNom`, which is the one thing that package does that this
one did not: a prediction on its own answers nothing, and the question a
reader actually has is what the number would be if one value were
different. So rows accumulate and are drawn against a common scale, so
two of them can be compared. Each row shows its estimate as a dot; no
uncertainty range is drawn beside it, by owner decision on review
finding `D-1`. The bounds are still carried in each record for anyone
working with the numbers rather than reading the screen.

## Usage

``` r
mm_calculator_comparison(
  saved,
  threshold,
  higher_is = "worse",
  subject = "patient",
  specs = NULL
)
```

## Arguments

- saved:

  A list of kept rows, each with `values`, `pred` and `extrapolated`.
  `lower` and `upper` are accepted and retained on the record but are
  not read: nothing is drawn from them (finding `D-1`).

- threshold:

  The risk the bands are relative to.

- higher_is:

  Whether a higher prediction is the worse outcome.

- subject:

  What one row is, in the singular.

- specs:

  The schema's predictors.

## Value

A Shiny tag, or `NULL` when nothing has been kept.
