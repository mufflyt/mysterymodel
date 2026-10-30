# Fit the declared model with rms

Builds the formula from the project, fits it with
[`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html), and keeps
everything a later step needs: the fit, its `datadist`, the formula it
was actually given, a prediction schema and a fingerprint of the
coefficients.

## Usage

``` r
mm_model(project, cohort, nonlinear = NULL, interactions = NULL, knots = 4L)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md)
  configuration.

- cohort:

  The development data. When the project declares a split, only rows
  below `split_at` are used, and the held-out rows are returned
  untouched for later scoring.

- nonlinear:

  Character vector of continuous predictors to fit with restricted cubic
  splines.

- interactions:

  List of length-two character vectors naming prespecified interactions.
  Exploratory discovery is not this argument.

- knots:

  Knots for each spline term.

## Value

An object of class `mm_model`.

## Details

`x` and `y` are kept on the fit, because validation and calibration need
them and a fit without them fails later for reasons that do not name
this decision. That is the only patient-level retention: the design
matrix the model was fitted on and the outcome it was fitted to.

Nothing else of the cohort survives, and the mechanism is worth naming
because the default behaviour is the opposite. A formula keeps the
environment it was built in,
[`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) stores that
environment on `fit$terms` and `fit$sformula`, and a formula built in
this function's own frame would hold the cohort, the development rows
and the split. The identifier column in particular is in none of them,
so a saved model cannot carry patient identifiers into a place the data
was never meant to go. The formula is built in
[`baseenv()`](https://rdrr.io/r/base/environment.html) to keep that
true.

Strong hierarchy is enforced rather than assumed: an interaction is
refused unless both of its main effects are in the project's predictors.
The specification requires that an interaction only be usable with its
constituent main effects, and a formula is the last place to find out.

Which rows are modelled is decided once, before anything is fitted, and
the `datadist`, the fit and the prediction schema are all built from
that one frame. `rms` would otherwise drop a row with a missing model
variable at fit time, leaving three parts of the same object describing
three different samples: the fit estimated on the complete rows, the
schema taking its ranges and levels from the supplied ones, and the
datadist taking the limits that set a nomogram's drawn axis. A value no
fitted row carried then came back labelled as interpolation, and the
printed nomogram reached values the model was never estimated on.

The difference is reported rather than absorbed, as `n_supplied`,
`n_incomplete` and `incomplete_by`, and warned about. It matters most
for the sample-size gate, which would otherwise judge a sample larger
than the one that exists and so be most lenient exactly where it should
be strictest. Deciding the analysis sample belongs in
[`mm_clean()`](https://mufflyt.github.io/mysterymodel/reference/mm_clean.md),
where the exclusion reaches the flow diagram, not in `na.action`.

A factor level carried only by dropped rows is removed and named in
`lost_levels`. It has no rows left to estimate it from, `rms` answers
one with a singular Hessian whose message identifies neither the
variable nor the level, and leaving it in the schema would let
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
admit a level the model cannot score.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 300, seed = 1)
project <- mm_project("uds", "event",
                      c("age", "bmi", "sex", "prior_uti"),
                      cohort = cohort)
fit <- mm_model(project, cohort, nonlinear = "age",
                interactions = list(c("prior_uti", "sex")))
#> Warning: the development sample may be too small for this model: 300 rows is 1097 short of the 1397 a model of 7 parameter(s) needs at 9.3% prevalence for 90% shrinkage. Coefficients from a sample this size are expected to be overfitted; see the adequacy element of the returned object.
fit
#> <mm_model: uds>
#>   formula    .mm_y ~ rms::rcs(age, 4) + bmi + sex + prior_uti + prior_uti:sex
#>   developed  300 rows, 28 events
#>   parameters 7 non-intercept, 1097 short of the sample they need
#>   apparent C 0.7126
#>   fingerprint fba075b46006604c
```
