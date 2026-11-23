# Refuse a declared event level that nothing in the outcome carries

[`mm_event_indicator()`](https://mufflyt.github.io/mysterymodel/reference/mm_event_indicator.md)
takes a declared `positive_class` on trust, which is right for
everything
[`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md)
validates: a project given a cohort refuses a level the outcome does not
carry at plan time, so by the time the indicator is built the level is
known to exist.

## Usage

``` r
mm_check_positive(values, positive, caller)
```

## Arguments

- values:

  The outcome column.

- positive:

  The declared event level, or `NULL`.

- caller:

  The function to name in the message.

## Value

`TRUE`, invisibly, or an error.

## Details

The recalibration and decision-curve functions take an outcome and a
`positive` with no project between them, so nothing has checked it.
Without this, naming a level that does not exist returns an indicator of
all zeros, and the caller is then told their outcome has one class. That
is true and it is not the problem: which value was expected should be
named. It cannot tell a misnamed level from a sample that genuinely
carries no events, so it reports what the outcome does hold and says
both readings are open. The same mistake, an unrecognised level quietly
becoming something else, was finding W-3 in the calculator.
