# Specify a prediction model before fitting one

The object every other step reads. It records what is being predicted,
from which columns, and how the data divides into development and
held-out, so no later step has to guess and no two steps can quietly
disagree.

## Usage

``` r
mm_spec(
  outcome,
  predictors,
  data = NULL,
  split_var = NULL,
  split_at = NULL,
  seed = 1978L
)
```

## Arguments

- outcome:

  Length-one character naming the outcome column.

- predictors:

  Character vector of candidate predictor columns. The order is kept,
  because it is the order a report presents them in.

- data:

  Optional data frame. When given, every name in `outcome`, `predictors`
  and `split_var` must be one of its columns, and the error names the
  ones that are not. The data itself is not stored.

- split_var:

  Optional length-one character naming the column that separates
  development from held-out data, most often a year.

- split_at:

  Optional single value. Rows with `split_var < split_at` are
  development and the rest are held out. Goes with `split_var`.

- seed:

  Single whole number, recorded here so that a later resampling step
  cannot invent one of its own.

## Value

An object of class `mysterymodel_spec`: a list with components
`outcome`, `predictors`, `split_var`, `split_at` and `seed`.

## Details

Nothing is fitted and no row is read. `mm_spec()` records choices and
refuses incoherent ones. That is the point: the specification is what a
reviewer should be able to read and check before a model exists, which
is the opposite of recovering it afterwards from the code that happened
to run.

## Examples

``` r
mm_spec("matched", c("step_1_score", "research_count", "sex"))
#> <mysterymodel spec>
#>   outcome    matched
#>   predictors 3: step_1_score, research_count, sex
#>   split      none
#>   seed       1978

# Temporal validation: develop before 2023, hold out 2023 onwards.
mm_spec("matched", c("step_1_score", "research_count"),
        split_var = "app_year", split_at = 2023)
#> <mysterymodel spec>
#>   outcome    matched
#>   predictors 2: step_1_score, research_count
#>   split      app_year < 2023 develops, the rest is held out
#>   seed       1978
```
