# Variance inflation, per variable and per parameter

THE GATE IS PER VARIABLE AND THE DETAIL IS PER PARAMETER, which is the
requirement `inst/capability-matrix.md` finding 3 states and the reason
it states it: [`rms::vif()`](https://rdrr.io/pkg/rms/man/vif.html) is
per model-matrix parameter, and the bases of one restricted cubic spline
are collinear with each other by construction. On an ordinary spline
model the per-parameter figures reach 126 and a check that gated on them
would refuse every model fitted with `nonlinear =`. The per-variable
figure alone reassures without detail, so both are returned and both are
labelled.

## Usage

``` r
mm_vif_check(model, max = 4)
```

## Arguments

- model:

  An
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md),
  or the [`rms::lrm`](https://rdrr.io/pkg/rms/man/lrm.html) fit inside
  one.

- max:

  Flag a VARIABLE at or above this variance inflation factor. The
  default of 4 is the square of the conventional `sqrt(VIF) > 2` flag:
  below it a coefficient is readable.

## Value

A list with the per-variable `gvif` table, the sorted per-parameter
`vif` vector, `flagged` (the per-parameter subset at or above `max`),
`flagged_variables`, `ok` (decided on the per-variable figure), and a
one-line `reason` naming both.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 250, seed = 5)
fit <- suppressWarnings(mm_model(
  mm_project("vif", "event", c("age", "bmi"), cohort = cohort), cohort))
mm_vif_check(fit)$reason
#> [1] "VIF: per variable: highest 1.00 (age, 1 df), none at or above 4; per parameter: highest 1.00 (age), none at or above 4"
```
