# The standing caveats, written for whoever is reading them

Two readers need two different pages. A clinician reading a risk about
someone else needs to be told that the number is not advice and that the
model cannot see the person in front of them. The person the row is
about, reading their own prediction, needs something else entirely: that
the model describes people who share their values and not them, that a
number is not a verdict, and that it was fitted on people who came
before them. The clinical page handed to an applicant reads as a warning
about medical advice, which is both wrong and faintly absurd.

## Usage

``` r
mm_calculator_disclaimer(
  subject = "patient",
  audience = c("clinician", "self")
)
```

## Arguments

- subject:

  What one row is, in the singular.

- audience:

  Who is reading: a `"clinician"` scoring someone else, or the `"self"`
  the row is about, reading their own prediction.

## Value

A Shiny tag.

## Details

Written in the caller's noun throughout, so a page about applicants does
not warn about patients.
