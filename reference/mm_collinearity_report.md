# All three collinearity diagnostics on a fitted model

Runs
[`mm_vif_check()`](https://mufflyt.github.io/mysterymodel/reference/mm_vif_check.md)
on the fit and
[`mm_redun_check()`](https://mufflyt.github.io/mysterymodel/reference/mm_redun_check.md)
and
[`mm_cor_pairs()`](https://mufflyt.github.io/mysterymodel/reference/mm_cor_pairs.md)
on the development predictors, and reports them together.

## Usage

``` r
mm_collinearity_report(model, cohort, max_vif = 4, max_r2 = 0.9, max_rho = 0.5)
```

## Arguments

- model:

  An
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- cohort:

  The rows the model was developed on.

- max_vif, max_r2, max_rho:

  Passed to the three checks above.

## Value

A list with `vif`, `redun`, `pairs`, `ok` (the VIF and redundancy
checks; the pair matrix is advisory and does not gate), and `text`.

## Details

The cohort is required and is checked against the model's development
fingerprint, because
[`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
does not retain the rows it was fitted on. Collinearity measured on a
different frame of the same shape would describe a different sample and
read as though it described the fit.

The outcome column is removed before the redundancy and correlation
checks: a predictor correlated with the OUTCOME is the point of the
model, not a problem with it.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 250, seed = 5)
fit <- suppressWarnings(mm_model(
  mm_project("collin", "event", c("age", "bmi"), cohort = cohort), cohort))
cat(mm_collinearity_report(fit, cohort)$text)
#> VIF: per variable: highest 1.00 (age, 1 df), none at or above 4; per parameter: highest 1.00 (age), none at or above 4
#>   redundancy: none at R2 >= 0.9; highest is age at 0.000
#>   pairs: no numeric pair at |rho| >= 0.5
```
