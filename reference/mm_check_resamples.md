# Check a resample count before anything is drawn

One contract, read by every entry point that resamples, so a public
function cannot validate what a lower-level one then truncates.

## Usage

``` r
mm_check_resamples(B)
```

## Arguments

- B:

  The count to check.

## Value

`B` as a whole number, invisibly.

## Details

`as.integer(2.7)` is 2. A caller who asked for 2.7 resamples asked for
something that does not exist, and silently giving them 2 answers a
question they did not pose. The same reasoning covers `NA`, `NaN`, the
infinities, a vector, and a string that looks like a number: each is
refused by name rather than coerced into whatever
[`as.integer()`](https://rdrr.io/r/base/integer.html) makes of it. An
integer-valued double such as `200.0` is accepted, because it is a count
written with a decimal point.

The floor is 1 rather than something larger. One resample is computable
and useless, and the useful threshold is already enforced elsewhere: the
full-process bootstrap reports itself inadequate below four fifths of
`B`, and so now does the fixed-model row. An arbitrary floor here would
duplicate that judgement in a worse place.

Validation happens before any seed is set or any resample drawn, so a
refused call leaves the random-number state exactly as it found it.
