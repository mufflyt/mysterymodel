# Raise what the leakage scan found, blocking only on duplication

Raise what the leakage scan found, blocking only on duplication

## Usage

``` r
mm_report_leakage(findings, outcome)
```

## Arguments

- findings:

  From
  [`mm_leakage()`](https://mufflyt.github.io/mysterymodel/reference/mm_leakage.md).

- outcome:

  The outcome's name, for the message.

## Value

`invisible(findings)`, after erroring on any tier 1 finding and warning
on the rest.
