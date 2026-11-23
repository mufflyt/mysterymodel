# Per-stratum intercept corrections

One constant per stratum, for the analysis that asks whether a single
correction serves every group. A stratum below `min_n` rows, or with no
outcome variation, returns `NA` and a reason rather than a number: a
constant fitted on fourteen rows is noise, and printing it beside one
fitted on four hundred invites reading them alike.

## Usage

``` r
mm_recal_by(lp, y, stratum, cluster = NULL, min_n = 50, positive = NULL)
```

## Arguments

- lp:

  Linear predictors from the FROZEN model, not refitted here. For an
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  these are `fitted(model, scale = "link")` on new rows.

- y:

  The observed outcome, in any form
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  accepts.

- stratum:

  The grouping, one value per row.

- cluster:

  An identifier for rows that are not independent, or `NULL`.

- min_n:

  The fewest rows a stratum may have and still be estimated.

- positive:

  The level that means the event, as in
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

## Value

A data frame with one row per stratum.

## Details

In the source project this analysis REJECTED per-stratum constants:
fitted on one cycle they were worse than the global constant for both
strata on the next, and the apparent subgroup gap turned out to be a
sampling artefact of a single cycle. It is here so that comparison can
be made, not because stratifying is the expected answer.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 400, seed = 9)
fit <- suppressWarnings(mm_model(
  mm_project("recal", "event", c("age", "bmi"),
             positive_class = 1, cohort = cohort), cohort))
lp <- as.numeric(fit$fit$linear.predictors)
mm_recal_by(lp, cohort$event, cohort$sex, min_n = 50, positive = 1)
#>   stratum          a        se   n events
#> 1  female -0.2143959 0.2141218 300     24
#> 2    male  0.4522599 0.2759366 100     16
#>                                                                                                                  reason
#> 1  intercept correction -0.2144 (SE 0.2141, model-based, rows treated as independent) from 300 rows, 24 event(s) (8.0%)
#> 2 intercept correction +0.4523 (SE 0.2759, model-based, rows treated as independent) from 100 rows, 16 event(s) (16.0%)
```
