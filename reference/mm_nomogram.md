# Draw the nomogram, and prove it agrees with the model

Builds the canonical
[`rms::nomogram()`](https://rdrr.io/pkg/rms/man/nomogram.html) from the
exact fitted model, with the same `datadist` it was fitted under, then
reads the drawn nomogram back the way a clinician reads it and checks
that the answer matches
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md).

## Usage

``` r
mm_nomogram(
  model,
  out_dir = NULL,
  tolerance = 1e-06,
  width = 13,
  height = 9,
  fun_at = NULL
)
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- out_dir:

  Directory for the exported files. `NULL` draws nothing.

- tolerance:

  Largest absolute difference in predicted risk tolerated between the
  nomogram and
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
  at tabulated values.

- width, height:

  Inches. The default is the landscape shape the specification asks for.

- fun_at:

  Risk ticks for the printed risk axis.

## Value

An object of class `mm_nomogram`.

## Details

A nomogram that disagrees with the model it was drawn from is worse than
no nomogram, because it is a published instrument giving wrong risks. So
the agreement is asserted rather than assumed, which is what the
specification's nomogram contract requires.

The check is made at the nomogram's own tabulated tick values, where
agreement holds to machine precision. Reading *between* ticks is a
different matter: a spline term curves between printed ticks and linear
interpolation across them does not, so an off-tick reading carries the
axis's resolution error. That is a property of every printed nomogram
and of the clinician reading it, not a defect here, and `reading_error`
reports its size instead of hiding it.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 300, seed = 1)
project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                      cohort = cohort)
fit <- mm_model(project, cohort, nonlinear = "age")
#> Warning: the development sample may be too small for this model: 300 rows is 22175 short of the 22475 a model of 5 parameter(s) needs at 9.3% prevalence for 90% shrinkage. Coefficients from a sample this size are expected to be overfitted; see the adequacy element of the returned object.
nom <- mm_nomogram(fit, out_dir = NULL)
nom
#> <mm_nomogram>
#>   axes            age, bmi, sex
#>   profiles checked 20 at tabulated ticks
#>   worst gap vs mm_predict() 5.55e-17 (tolerance 1e-06)
#>   off-tick reading error    0.0022 in risk, midway between ticks
```
