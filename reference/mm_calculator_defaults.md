# The value each input starts at, and returns to

One definition read by the form and by the reset button, so that what
"reset" restores cannot drift from what the form opened with.

## Usage

``` r
mm_calculator_defaults(model)
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

## Value

A named list, one element per predictor.

## Details

Both come from the `datadist`'s "Adjust to" row, which holds the median
of each continuous predictor and the commonest level of each categorical
one. That is the cohort's most ordinary member, and it is where the
model is most certain, because the standard error of a prediction grows
with distance from the middle of the data the model was fitted on.
Opening there means the first number a reader sees is the one the model
is best placed to make.

The obvious alternative, each factor's first level, is what this used to
do, and it is worse in a way that is easy to miss: first levels are
chosen for the model's arithmetic, not for how common they are, and
combining one per predictor can produce somebody almost nobody is. On
the ENT applicant model it opened on an international graduate needing
work authorisation on a second attempt with no Step 2 score, whose
interval was among the widest in the cohort.

A level the fit never saw cannot be offered, so an "Adjust to" value
that is not in the schema falls back to the first level. That happens
when a level was carried only by rows dropped for incompleteness.
