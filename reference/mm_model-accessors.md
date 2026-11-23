# Standard accessors for a fitted mysterymodel

[`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
stores the fitted `rms` object at `model$fit`, and until these methods
existed a caller had to reach into it to get a coefficient. Each method
below delegates where delegation gives the right statistical semantics
and does the work explicitly where it does not.

Three of them could not delegate, which is why they are written out
rather than aliased. Each case was established by running the generic
against a fitted `lrm` object, not inferred from the object's shape:

- [`stats::fitted()`](https://rdrr.io/r/stats/fitted.values.html) on an
  [`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) fit returns
  `NULL`, because `lrm()` does not populate `fitted.values`. A
  delegating method would hand back `NULL` and look like it worked.

- [`stats::confint()`](https://rdrr.io/r/stats/confint.html) on such a
  fit **fails**: it dispatches to `confint.glm()`, begins profiling, and
  errors with `$ operator is invalid for atomic vectors`. There is
  therefore no profile-likelihood interval to preserve, and the Wald
  interval here is a documented substitute rather than a silent one.

- `stats::summary()` on an `rms` fit reports **effect sizes** across the
  predictor ranges, which is a different object from a model summary. A
  delegating `summary.mm_model()` would return something a reader would
  misread, so this one composes its own and names where the other lives.

## Usage

``` r
# S3 method for class 'mm_model'
coef(object, ...)

# S3 method for class 'mm_model'
vcov(object, ...)

# S3 method for class 'mm_model'
formula(x, ...)

# S3 method for class 'mm_model'
nobs(object, ...)

# S3 method for class 'mm_model'
fitted(object, scale = c("response", "link"), ...)

# S3 method for class 'mm_model'
residuals(object, type = "deviance", ...)

# S3 method for class 'mm_model'
confint(object, parm, level = 0.95, ...)

# S3 method for class 'mm_model'
summary(object, level = 0.95, ...)

# S3 method for class 'summary.mm_model'
print(x, ...)
```

## Arguments

- object, x:

  A `mm_model` from
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- ...:

  Passed to the underlying `rms` method where one is used.

- scale:

  `"response"` for probabilities, `"link"` for the linear predictor.

- type:

  Residual type, passed to `rms`.

- parm:

  Coefficients to report; defaults to all.

- level:

  Coverage.

## Value

As documented per method below.

## Functions

- `coef(mm_model)`: Model coefficients, names preserved.

- `vcov(mm_model)`: The coefficient variance-covariance matrix.

- `formula(mm_model)`: The fitted formula. Its response term is the
  package's internal recoded outcome (`.mm_y`), not the column named in
  `mm_project(outcome = )`; `object$project$outcome` is that column.

- `nobs(mm_model)`: The number of observations the model was fitted on,
  which is the development rows after complete-case exclusion, not the
  rows supplied. `object$n_supplied` and `object$n_held` are the other
  two counts, and they are different numbers on purpose.

- `fitted(mm_model)`: Fitted values. `scale = "response"` (the default)
  gives predicted probabilities; `scale = "link"` gives the linear
  predictor. The scale is an argument rather than an assumption because
  [`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) leaves
  `fitted.values` empty, so there is no inherited convention to follow.

- `residuals(mm_model)`: Residuals. `type` is passed to
  [`rms::residuals.lrm()`](https://rdrr.io/pkg/rms/man/residuals.lrm.html),
  which supports `"ordinary"`, `"li.shepherd"`, `"score"`, `"pearson"`,
  `"deviance"`, `"pseudo.dep"`, `"partial"`, `"dfbeta"` and `"gof"`. The
  default is `"deviance"`. `"score"`, `"partial"` and `"dfbeta"` return
  a matrix rather than a vector, and the types are not interchangeable:
  a residual's interpretation follows its definition, so read
  [`?rms::residuals.lrm`](https://rdrr.io/pkg/rms/man/residuals.lrm.html)
  before comparing two of them.

- `confint(mm_model)`: Wald confidence intervals on the coefficients,
  from [`vcov()`](https://rdrr.io/r/stats/vcov.html).

  **These are Wald intervals, and that is a substitute rather than a
  preference.**
  [`stats::confint()`](https://rdrr.io/r/stats/confint.html) on an
  [`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) fit dispatches to
  `confint.glm()`, which attempts profile likelihood and errors, so no
  profile interval is available to return. They are intervals on the
  coefficient scale and are not the interval
  [`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
  reports on the c-statistic, which is a DeLong interval on a
  performance measure. Reading one as the other misreports the model.

- `summary(mm_model)`: A summary of the fitted model: its call, the
  three row counts, the parameter budget, and the coefficients with
  their Wald intervals.

  **It reports no performance.** Discrimination, calibration and
  bootstrap optimism come from
  [`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md),
  and a fitted-model summary that printed them beside the coefficients
  would invite a reader to treat an apparent number as a validated one.
  `rms::summary()` on `object$fit` is a different object again: effect
  sizes across predictor ranges.

- `print(summary.mm_model)`: Print method for the summary.

## See also

[`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
for performance, which these do not report.
