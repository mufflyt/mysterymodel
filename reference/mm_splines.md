# Draw each continuous predictor as a straight line and as a spline

A diagnostic for the degrees of freedom a continuous predictor is given.
Fitting one as a straight line is a modelling decision exactly as much
as fitting it with a spline, and it is the decision this package makes
by default and says nothing about: `nonlinear` is `NULL` unless an
analyst names the predictor. This function makes both allocations
visible and quantifies what choosing between them changes.

## Usage

``` r
mm_splines(
  project,
  cohort,
  predictors = NULL,
  knots = 4L,
  at = NULL,
  n_points = 120L,
  plot = TRUE
)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- cohort:

  The cohort. Development rows only, under the same eligibility rule
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  fits under.

- predictors:

  Which continuous predictors to draw. Defaults to all of the project's
  that can carry a spline.

- knots:

  Knots for the spline arm, as
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  takes them.

- at:

  Reference profile, as a one-row data frame or a named list. The
  default holds continuous predictors at their median and categorical
  ones at their most common level, and the profile used is returned.

- n_points:

  Points at which each curve is evaluated.

- plot:

  Draw the panels. `FALSE` returns the curves and draws nothing.

## Value

An object of class `mm_splines`: `curves`, one row per predictor and
evaluation point with the risk each allocation implies; `summary`, one
row per predictor with the degrees of freedom and the largest risk gap
between the two; and the `reference` profile they were drawn at.

## Details

It decides nothing. For each continuous predictor it fits the model
twice, once with that predictor linear and once with it splined,
everything else held as specified, and reports the predicted risk each
implies across the predictor's observed range.

## Why there is no test here, and no recommendation

Fitting a spline, reading the aggregate nonlinear term's p-value and
dropping back to a straight line when it is not significant is a pretest
estimator: the model's shape becomes a function of the outcome, and the
optimism of that choice is corrected by nothing downstream. It is the
same error as choosing interactions on the development data and then
validating the chosen model as though it had been prespecified.
`rms::anova()` prints the aggregate nonlinear row immediately beside the
block test, so the temptation is one glance away.

The allocation belongs in the analysis plan, decided on what the
predictor is rather than on what this cohort's outcome does. Harrell's
advice is to spend the degrees of freedom by prespecification, more on
predictors expected to matter, within the sample's budget. What this
function supplies is the arithmetic for that conversation: the degrees
of freedom each allocation costs and the largest risk difference between
them.

## What is plotted, and what is deliberately not

Both curves are **adjusted**: every other predictor is held at the
reference profile, so the two curves differ only in how this predictor
enters. A binned observed event rate is not drawn over them, however
natural that looks, because a marginal event rate and an adjusted curve
are different quantities and the eye would compare them anyway. A rug of
the observed values is drawn instead, which is comparable: it shows
where the data actually is, and therefore which parts of either curve
rest on nothing.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 600, prevalence = 0.15, seed = 1978)
project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                      positive_class = 1, cohort = cohort)
shapes <- mm_splines(project, cohort, plot = FALSE)
shapes$summary
#>   predictor parameters_linear parameters_spline added_parameters
#> 1       age                 3                 5                2
#> 2       bmi                 3                 5                2
#>   largest_risk_gap at_value
#> 1       0.29929645     23.5
#> 2       0.09517398     48.6
#>                                                                                       note
#> 1 drawn over the observed range 23.5 to 95, every other predictor at the reference profile
#> 2 drawn over the observed range 15 to 48.6, every other predictor at the reference profile
```
