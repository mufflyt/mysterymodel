# Fit the declared model with rms

Builds the formula from the project, fits it with
[`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html), and keeps
everything a later step needs: the fit, its `datadist`, the formula it
was actually given, a prediction schema and a fingerprint of the
coefficients.

## Usage

``` r
cp_model(project, cohort, nonlinear = NULL, interactions = NULL, knots = 4L)
```

## Arguments

- project:

  A
  [`cp_project()`](https://mufflyt.github.io/mysterymodel/reference/cp_project.md)
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

An object of class `cp_model`.

## Details

`x` and `y` are kept on the fit, because validation and calibration need
them and a fit without them fails later for reasons that do not name
this decision.

Strong hierarchy is enforced rather than assumed: an interaction is
refused unless both of its main effects are in the project's predictors.
The specification requires that an interaction only be usable with its
constituent main effects, and a formula is the last place to find out.

## Examples

``` r
cohort <- cp_synthetic_cohort(n = 300, seed = 1)
project <- cp_project("uds", "event",
                      c("age", "bmi", "sex", "prior_uti"),
                      cohort = cohort)
fit <- cp_model(project, cohort, nonlinear = "age",
                interactions = list(c("prior_uti", "sex")))
#> Warning: the development sample may be too small for this model: 300 rows is 1097 short of the 1397 a model of 7 parameter(s) needs at 9.3% prevalence for 90% shrinkage. Coefficients from a sample this size are expected to be overfitted; see the adequacy element of the returned object.
fit
#> <cp_model: uds>
#>   formula    .cp_y ~ rms::rcs(age, 4) + bmi + sex + prior_uti + prior_uti:sex
#>   developed  300 rows, 28 events
#>   parameters 7 non-intercept, 1097 short of the sample they need
#>   apparent C 0.7126
#>   fingerprint 97af98a72772f7d7
```
