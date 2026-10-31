# Create a validated analysis configuration

The analysis plan, written down and checked before anything is fitted.
Every later step reads this object, so no step has to guess and no two
steps can quietly disagree.

## Usage

``` r
mm_project(
  slug,
  outcome,
  predictors,
  positive_class = NULL,
  cohort = NULL,
  split_var = NULL,
  split_at = NULL,
  cluster_id = NULL,
  nonlinear = NULL,
  interactions = NULL,
  knots = 4L,
  seed = 1978L
)
```

## Arguments

- slug:

  Short study identifier, used in artifact paths.

- outcome:

  Length-one character naming the outcome column.

- predictors:

  Character vector of candidate predictor columns. The order is kept,
  because it is the order a report presents them in.

- positive_class:

  Optional value naming the event level of `outcome`. Checked against
  the observed values when `cohort` is supplied, because an inverted
  positive class silently inverts every reported risk.

- cohort:

  Optional data frame. When supplied, every column named here must exist
  in it, the outcome must vary, and `positive_class` must be one of the
  outcome's observed values. The cohort itself is not stored.

- split_var:

  Optional length-one character naming the column that separates
  development from held-out data, most often a year.

- split_at:

  Optional single value. Rows with `split_var < split_at` are
  development and the rest are held out.

- cluster_id:

  Optional length-one character naming the column that identifies
  repeated observations on one patient, for clustered resampling.

- nonlinear:

  Optional character vector of continuous predictors to fit with
  restricted cubic splines. Part of the plan rather than of the fitting
  call, because how many degrees of freedom a continuous predictor is
  given is a prespecified choice: section 78 of the specification asks
  the configuration to carry the spline and interaction terms, and a
  plan that lives in whichever
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  call ran is not one a reviewer can check against a protocol. Left
  `NULL` the project records no shape, which is not the same as
  recording that every continuous predictor is straight:
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  then takes its own argument without calling it a departure, because
  there is no plan to depart from.
  [`mm_splines()`](https://mufflyt.github.io/mysterymodel/reference/mm_splines.md)
  shows what the choice is worth before it is written down.

- interactions:

  Optional list of length-two character vectors naming prespecified
  interaction blocks. Exploratory discovery is not this argument;
  [`mm_interactions()`](https://mufflyt.github.io/mysterymodel/reference/mm_interactions.md)
  reports evidence and selects nothing.

- knots:

  Knots for each spline term.

- seed:

  Single whole number, recorded here so that a later resampling step
  cannot invent one of its own.

## Value

An object of class `mm_project`.

## Details

Nothing is fitted and no row is modelled. `mm_project()` records choices
and fails closed on combinations that cannot be meant. That is the
point: the configuration is what a reviewer should be able to check
against the protocol, rather than reconstruct afterwards from whichever
code ran.

## Examples

``` r
mm_project("uds", "event", c("age", "bmi", "sex"))
#> <mm_project: uds>
#>   outcome    event
#>   predictors 3: age, bmi, sex
#>   split      none
#>   shape      every continuous predictor linear
#>   seed       1978

# Temporal validation: develop before 2023, hold out 2023 onwards.
mm_project("uds", "event", c("age", "bmi"),
           split_var = "year", split_at = 2023)
#> <mm_project: uds>
#>   outcome    event
#>   predictors 2: age, bmi
#>   split      year < 2023 develops, the rest is held out
#>   shape      every continuous predictor linear
#>   seed       1978
```
