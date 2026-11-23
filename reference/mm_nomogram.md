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
  width = NULL,
  height = NULL,
  fun_at = NULL,
  funlabel = "Predicted risk",
  labels = NULL,
  level_case = c("title", "asis"),
  id = NULL
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

  Inches. `NULL`, the default, sizes the sheet to the model: a
  nomogram's rows do not get shorter when there are more of them, so a
  page of fixed height crushes a model with many predictors into an
  unreadable sheet. The ENT applicant model, 27 axes on the 9 inches
  that suited 3, printed row labels across their own tick marks.

- fun_at:

  Risk ticks for the printed risk axis.

- funlabel:

  The printed risk axis's own label. Not every model this package fits
  predicts a risk: the same machinery drew a nomogram for the chance of
  matching into a residency, where "Predicted risk" is the wrong noun on
  a sheet handed to the person it is about.

- labels:

  Printed names for the predictor axes, as a named character vector. The
  usual way to set these is
  [`Hmisc::label()`](https://rdrr.io/pkg/Hmisc/man/label.html) on the
  cohort before fitting, which `rms` carries into the drawn sheet on its
  own; this argument is for relabelling a model that is already fitted.
  Renaming happens after the sheet has been checked against
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
  and never before, so the check matches axes to predictors by the names
  the fit gave them and a printed name cannot change what was verified.

- level_case:

  What to do with the level text a categorical axis prints. Levels
  arrive as they were typed into a data-entry form, so a published sheet
  carries `no AOA at school` down the middle of the page. `"title"`, the
  default, title cases them for printing and leaves a word carrying a
  capital of its own alone, so `AOA` and `USMLE` survive. `"asis"`
  prints them exactly as the fit holds them. Like `labels`, this happens
  after the sheet has been checked and never before.

- id:

  Optional text appended to the exported filenames, as
  `<slug>_nomogram_<id>.pdf`. Two fits of the same project otherwise
  write the same three filenames, and the export refuses to overwrite,
  so this is how both sheets reach disk. A run id, a date, or whatever
  distinguishes the fits; it is used verbatim.

## Value

An object of class `mm_nomogram`. Its `nomogram` element is the sheet
that was checked, carrying the levels the fit holds; `drawn` is the copy
that was printed, with any renaming and title casing applied.

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
and of the clinician reading it, not a defect here. `reading_error`
bounds it: no reading between the printed ticks can differ from
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
by more than that figure. See
[`mm_reading_error()`](https://mufflyt.github.io/mysterymodel/reference/mm_reading_error.md)
for how a bound is reached without searching the joint space, and for
the three things it does not cover.

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
#>   between-tick reading      0.00881 in risk at most, anywhere off the ticks
#>                             age is the coarsest axis
```
