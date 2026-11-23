# Title case that leaves an acronym alone

Factor levels arrive as they were typed into a data-entry form:
"member", "senior elections", "no AOA at school". Printed in a dropdown
beside sentence-cased labels they read as unfinished. Naive title case
is worse, because it turns AOA into Aoa and USMLE into Usmle, so a word
carrying a capital of its own is left exactly as it is, and the short
joining words stay lowercase unless they open or close the phrase.

## Usage

``` r
mm_title_case(x)
```

## Arguments

- x:

  A character vector.

## Value

The same vector, title cased.

## Details

This changes what is shown and never what is submitted: the dropdown's
values stay the levels the fit knows, because
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
refuses a level it has not seen and a prettier spelling is exactly that.
