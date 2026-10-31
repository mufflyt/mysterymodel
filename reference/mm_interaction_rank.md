# Whether a candidate interaction is identifiable at all

The required invariant, computed before any model is fitted and without
needing one to converge. The aliased case is exactly the case that kills
[`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) with a singular
Hessian, so a check that read the design matrix off a fitted object
could never run on the candidate that most needs it.

## Usage

``` r
mm_interaction_rank(project, frame, pair, nonlinear = NULL, knots = 4L)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- frame:

  The development rows, after eligibility.

- pair:

  The two predictor names.

- nonlinear:

  Predictors fitted with splines.

- knots:

  Knots for those splines.

## Value

A list with `base_columns`, `base_rank`, `added_columns`, `added_rank`,
`identifiable`, `aliased` and `reason`.

## Details

Three outcomes are distinguished, because they are three different
facts:

- the interaction adds columns and the same number of dimensions, so it
  is identifiable and a test of it means something;

- it adds columns and fewer dimensions, so some of its terms are aliased
  with terms already in the model and the degrees of freedom a test
  would claim are not the degrees of freedom it has;

- it adds no dimension at all, so there is nothing to test. A p-value
  here is the most dangerous number in the whole screen: it is near one,
  it looks like evidence of no interaction, and it is evidence of
  nothing.

The reduced model's own rank is reported beside them, because a reduced
model that is already deficient makes every difference computed against
it unreliable, however healthy the increment looks.
