# Groups of axes of which exactly one applies to any patient

An interaction makes `rms` draw one axis per level of the categorical
partner, labelled `sex (prior_uti=no)` and `sex (prior_uti=yes)`. The
arithmetic handles it:
[`mm_nomogram_points()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram_points.md)
matches every value an axis holds fixed, so exactly one contributes and
the read-back agrees with the model to machine precision.

## Usage

``` r
mm_exclusive_axes(nom, model)
```

## Arguments

- nom:

  An `rms` nomogram.

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

## Value

A list, one element per group of two or more mutually exclusive axes,
naming the axes and the predictors that separate them.

## Details

A clinician reading the printed sheet has no such guard. They see two
axes both labelled `sex` and nothing on the page stops them scoring
both, which is an error no check inside this package can catch because
it happens on paper. So the groups are named in the returned object and
in what it prints, for whoever writes the caption.
