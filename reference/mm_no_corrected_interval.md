# Why a corrected c-statistic is reported without an interval

DeLong's standard error is for an apparent c-statistic computed once on
one sample. A corrected index is an apparent one minus an average
optimism, and neither
[`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html) nor
[`mm_full_process()`](https://mufflyt.github.io/mysterymodel/reference/mm_full_process.md)
returns the distribution of that difference, so there is nothing here to
put an interval around.

## Usage

``` r
mm_no_corrected_interval()
```

## Value

One sentence.

## Details

The recognised answer is a nested bootstrap: an outer loop resampling
the cohort, each iteration running the whole correction, and a
percentile interval taken over the corrected values it produces. That is
`B` times the work of the correction itself and is not implemented.
Reporting it as absent, with the reason, is what keeps the apparent
row's interval from being read down the column as though it applied
here.
