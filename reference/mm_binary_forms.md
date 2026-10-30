# Candidate 0/1 encodings of a column, where the meaning is unambiguous

A predictor can only be an exact copy of a binary outcome if it carries
the same two-valued information, so this answers a narrow question: can
this column be read as 0/1 without guessing. Numeric columns holding
only 0 and 1, logicals, and any column with exactly two observed values
qualify. Everything else does not, which is what keeps an arbitrary
string from being coerced into an outcome.

## Usage

``` r
mm_binary_forms(values)
```

## Arguments

- values:

  A candidate predictor column.

## Value

A list of encodings, each a list of `code` (0/1 integer with `NA`
preserved) and `label` (how it was read). Empty when the column cannot
be read as binary without guessing.

## Details

Two encodings are returned for a two-valued column, one per choice of
which value marks the event, because the labels are arbitrary and a
comparison that trusted them would miss a copy whose levels happen to
read backwards.
