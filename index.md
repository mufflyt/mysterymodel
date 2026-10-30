# mysterymodel

An opinionated workflow for building clinical prediction models that
survive peer review.

`mysterymodel` is not another modelling framework. The statistics are
done by engines that already do them well. What this package contributes
is the orchestration between them, and the methodological safeguards
that are easy to skip and expensive to skip.

## Status

Early, and deliberately so. The [implementation
specification](https://mufflyt.github.io/mysterymodel/inst/implementation-spec.md)
is the contract of record, kept as received; settled questions are
amended in the [decision
log](https://mufflyt.github.io/mysterymodel/inst/decisions.md). Section
14 requires a capability spike before any production module, and that
spike is done: [**capability matrix for `rms`
objects**](https://mufflyt.github.io/mysterymodel/inst/capability-matrix.md).

The whole §15 starting milestone now runs on synthetic data:
[`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md)
→
[`mm_clean()`](https://mufflyt.github.io/mysterymodel/reference/mm_clean.md)
→
[`mm_eda()`](https://mufflyt.github.io/mysterymodel/reference/mm_eda.md)
→
[`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
→
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
→
[`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
→
[`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md),
eight exported functions, 617 tests across 16 files, `R CMD check`
clean. What is still missing is named in the roadmap below and in the
[changelog](https://mufflyt.github.io/mysterymodel/NEWS.md): imputation
inside resampling is the largest gap, and the reporting end is not built
at all.

## Articles

Four, each on synthetic data, each showing its own numbers rather than
describing them:

- [**From a raw export to a checked
  nomogram**](https://mufflyt.github.io/mysterymodel/articles/mysterymodel.html).
  The whole pipeline in the order it has to run.
- [**Which number are you
  reporting?**](https://mufflyt.github.io/mysterymodel/articles/validation.html).
  Four c-statistics from one fit, what separates them, and the one
  caution about comparing two of them to each other.
- [**Reading the nomogram
  back**](https://mufflyt.github.io/mysterymodel/articles/nomogram.html).
  The agreement check done by hand, including the clamped-interpolation
  error that reported 1.1% for a patient whose risk was 0.6%.
- [**A complicated worked
  example**](https://mufflyt.github.io/mysterymodel/articles/worked-example.html).
  An awkward export, four competing plans, a leakage scan, and the
  nomogram read back. It exercises every function in the package and
  proves it does.

## The idea

Three ecosystems could do this work, and the package was planned around
using each for what it is best at:

|  | what it is best at |
|----|----|
| [**rms**](https://hbiostat.org/R/rms/) | regression, bootstrap internal validation, calibration, nomograms |
| [**easystats**](https://easystats.github.io/easystats/) | collinearity, assumption checks, parameters, interpretation, reporting |
| [**tidymodels**](https://www.tidymodels.org/) | resampling, feature-selection workflows, model comparison |

A fourth, [mlr3](https://mlr3.org/), is worth adding for computationally
heavy work on large data.

What actually ships is narrower, and the capability spike is why. `rms`
does the statistics; `pmsampsize` answers the sample-size question and
`pROC` supplies the interval on the c-statistic. **easystats and
tidymodels are not dependencies**: easystats has no prediction path for
an [`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) fit at all,
which takes most of its surface with it. [What the spike
settled](#what-the-spike-settled) has the measurements.

### How they compare

Approximate; some capabilities need extension packages.

| Capability               | easystats  | tidymodels | rms       | mlr3       |
|--------------------------|------------|------------|-----------|------------|
| Data cleaning            | strong     | strong     | limited   | strong     |
| EDA and descriptives     | excellent  | good       | good      | moderate   |
| Collinearity diagnostics | excellent  | good       | limited   | extensions |
| Feature selection        | moderate   | strong     | moderate  | excellent  |
| Model development        | good       | excellent  | excellent | excellent  |
| Nonlinear effects        | good       | excellent  | excellent | excellent  |
| Interaction assessment   | good       | good       | excellent | good       |
| Internal validation      | partial    | excellent  | excellent | excellent  |
| Calibration              | good       | good       | excellent | good       |
| Nomograms                | not native | not native | excellent | not native |
| Large-data workflows     | limited    | good       | limited   | strong     |
| Quarto reporting         | excellent  | excellent  | good      | good       |

`easystats` is an analysis and interpretation ecosystem. `tidymodels`
and `mlr3` are model development and evaluation frameworks. `rms` is the
one suited to a regression-based clinical prediction model intended for
publication.

## Design commitments

These are the decisions that make the package opinionated. They are
defaults, not locks. Where one is an intention rather than working code,
it says so.

- **Continuous predictors stay continuous.** Nonlinearity is assessed,
  not assumed away by categorising.
- **[`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) is the default
  binary-outcome model**, with `glmnet` and `glinternet` as
  alternatives.
- **Interactions are prespecified** and tested by likelihood ratio.
  Data-driven interaction discovery is reported as exploratory, and
  labelled that way.
- **Selection and imputation happen inside resampling**, never once
  beforehand. Doing it once leaks, and the leak flatters every number
  downstream. *Not yet implemented, and the package says so where it
  matters*:
  [`mm_full_process()`](https://mufflyt.github.io/mysterymodel/reference/mm_full_process.md)
  names imputation, selection and tuning as steps it does not
  re-execute, so its correction is not presented as validating a
  strategy that includes them. Fitting is complete-case in the meantime,
  with every excluded row counted and attributed
  ([DEC-003](https://mufflyt.github.io/mysterymodel/inst/decisions.md)).
- **Validation reports discrimination, calibration intercept and slope,
  Brier score, bootstrap optimism, and intervals.** Not discrimination
  alone. Each row names the method behind its interval and the event and
  non-event counts the interval rests on, and a row that cannot have one
  says why rather than leaving a blank.
- **Nomograms use the native `rms` machinery**, with readable labels,
  configurable axes, and pagination when a model outgrows one page.
- **No model-selection decision is made for you, and none is hidden.**

The reference is Frank Harrell’s *Regression Modeling Strategies*.

## Installation

``` r

# install.packages("pak")
pak::pak("mufflyt/mysterymodel")
```

## Usage

The analysis plan is written down and checked before anything is fitted,
so a reviewer can check it against the protocol rather than reconstruct
it afterwards from whichever code happened to run.

``` r

library(mysterymodel)

# Synthetic throughout, with known truth. The public repository carries no
# patient data, so every number below is reproducible from these lines.
uds_cohort <- mm_synthetic_cohort(n = 600, prevalence = 0.11, seed = 1978)

project <- mm_project(
  slug           = "uds",
  outcome        = "event",
  predictors     = c("age", "bmi", "sex"),
  positive_class = "1",
  cohort         = uds_cohort,
  split_var      = "year",
  split_at       = 2023,
  cluster_id     = "pid"
)

project
#> <mm_project: uds>
#>   outcome    event (event = 1)
#>   predictors 3: age, bmi, sex
#>   split      year < 2023 develops, the rest is held out
#>   cluster    pid
#>   seed       1978
```

[`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md)
fails closed on configurations that cannot be meant, rather than letting
them fail later as something harder to read. It implements the
conditions the specification names: an outcome that is also a predictor
(which reports perfect discrimination, and so reads as success), a
repeated predictor, temporal validation without a time field, a
clustered design without an ID column, an outcome that does not vary, a
positive class that is not an observed value, and a non-whole seed.

Eligibility is applied by named rule, and every row that leaves is
attributed to the rule that excluded it:

``` r

clean <- mm_clean(raw, rules = list(
  "aged 40 or over" = ~ age >= 40,
  "plausible BMI"   = ~ bmi >= 16 & bmi <= 55
))

clean
#> <mm_cohort>  600 in, 578 out, 22 excluded
#>      600  rows as supplied
#>      -18  aged 40 or over (did not meet the criterion)
#>      582  remaining
#>       -4  plausible BMI (did not meet the criterion)
#>      578  remaining
```

Rows in must equal rows out plus every exclusion, and
[`mm_clean()`](https://mufflyt.github.io/mysterymodel/reference/mm_clean.md)
errors rather than returning a cohort it cannot reconcile. A rule that
evaluates to `NA` is not a pass: those rows are excluded under their own
heading, because treating unknown eligibility as eligible and as
ineligible are different studies and the difference belongs in the flow
diagram.

[`mm_eda()`](https://mufflyt.github.io/mysterymodel/reference/mm_eda.md)
then describes the cohort with the denominator each percentage is taken
over and the missing count beside it, since a percentage whose
denominator quietly excludes missing rows reads as a fact about the
cohort when it is a fact about the rows that happened to be complete.

Then fit, validate and draw:

``` r

model <- mm_model(project, cohort, nonlinear = "age",
                  interactions = list(c("prior_uti", "sex")))
#> Warning: the development sample may be too small for this model: 389 rows
#> is 862 short of the 1251 a model of 7 parameter(s) needs at 11.1% prevalence
#> for 90% shrinkage. Coefficients from a sample this size are expected to be
#> overfitted; see the adequacy element of the returned object.

model$adequacy
#> <mm_adequacy>  adequate: FALSE
#>   development 389 rows, 43 events (11.1%)
#>   parameters  7 non-intercept, 6.1 events each (description, not the criterion)
#>   shrinkage   0.640 expected, heuristic
#>   requires    1251 rows, 139 events (Riley, from the fitted R2 of 0.097)
#>   389 rows is 862 short of the 1251 a model of 7 parameter(s) needs at 11.1% prevalence for 90% shrinkage

mm_validate(model, cohort, B = 200, full_process = TRUE)
#> <mm_validation>  full-process: TRUE
#>   columns: n, events/non-events, c-statistic with its 95% DeLong interval where one is estimable
#>   apparent                 n=389   43/346 C=0.6809 (0.5911-0.7707)
#>   bootstrap, fixed model   n=389   43/346 C=0.6211 no interval, see note  slope=0.7367
#>   bootstrap, full process  n=389   43/346 C=0.6153 no interval, see note  slope=0.7225
#>   held out                 n=189   19/170 C=0.7836 (0.6663-0.9009)  slope=1.4700
#>   Full process re-derives knot placement, datadist, factor levels per resample; 200 of 200 valid.

mm_nomogram(model, out_dir = "figures")
#> <mm_nomogram>
#>   axes            age, bmi, sex (prior_uti=no), sex (prior_uti=yes)
#>   profiles checked 24 at tabulated ticks
#>   worst gap vs mm_predict() 1.11e-16 (tolerance 1e-06)
#>   off-tick reading error    0.000633 in risk, midway between ticks
```

Four things in that output are deliberate.

**A model too large for its sample says so.** The gate is the Riley
requirement from `pmsampsize`, not the events-per-parameter rule, which
is reported as description and labelled as such. Note the agreement
between the two independent routes to the same conclusion: the heuristic
shrinkage of 0.640 and the bootstrap-estimated calibration slope of
0.737 below. One circularity is disclosed rather than hidden, in
[`?mm_adequacy`](https://mufflyt.github.io/mysterymodel/reference/mm_adequacy.md):
the requirement uses the fitted R-squared, so it answers whether this
sample was adequate for the model it produced, not how large a sample
should have been collected.

**Performance is reported per basis, never as one number.** The same
model measured four ways, and the spread is the point. The apparent row
carries no calibration slope, because scoring an unpenalized fit on its
own rows forces the intercept to zero and the slope to one: those two
numbers describe the estimator, not the model, so they are withheld
rather than printed beside a held-out slope of 1.47. The two corrected
rows carry no interval, and say why: DeLong describes an apparent
c-statistic, and an interval for a corrected one needs a nested
bootstrap that is not implemented
([DEC-006](https://mufflyt.github.io/mysterymodel/inst/decisions.md)).

The two bootstrap rows answer different questions. The fixed-model one,
from [`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html),
corrects the optimism of estimating coefficients for one formula. The
full-process one refits the whole strategy inside every resample, so
each resample gets its own spline knot placement, its own `datadist` and
its own factor-level handling, all three being learned from data. It
also states what it does **not** re-execute, which is imputation,
selection and tuning, because the package does not do them yet and a
strategy containing them would not be fully validated by it either.

They are different estimators with their own Monte Carlo error, so a
small gap between them is not evidence of anything.

Resampling is by whole patient when the project declares a cluster.
Resampling rows would treat two visits by one person as two independent
facts, which narrows every interval it touches.

**Invalid input is refused, not corrected.** A predictor that reproduces
the outcome under another name used to fit happily and report an
apparent c-statistic of 1.0000; `B = 2.7` ran two resamples; a predicted
probability of 1.5 was clamped into a plausible Brier score. Each is now
an error, because each silent correction produced a number a reader
would believe
([DEC-004](https://mufflyt.github.io/mysterymodel/inst/decisions.md)).
Perfect separation is the deliberate exception: with four events it is
as likely to be a small sample as a mistake, so it warns and the model
still fits.

**The nomogram is checked against the model, not assumed to match it.**
[`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
reads the drawn nomogram back the way a clinician does, summing points
and interpolating the printed axis without consulting the fit, then
refuses to return if the result disagrees with
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md).
Agreement holds to machine precision at tabulated ticks across linear,
spline and interaction models.

**The reading error between ticks is measured and reported.** A spline
curves between printed ticks and linear interpolation across them does
not, so an off-tick reading carries the axis’s own resolution error. It
is exactly zero for a model with no splines and about 0.001 to 0.005 in
risk with them. That belongs to every printed nomogram and to the
clinician reading it, so it is a stated number rather than an unexamined
assumption.

## Roadmap

Releases and acceptance gates are defined in full in the
[specification](https://mufflyt.github.io/mysterymodel/inst/implementation-spec.md),
section 12.

| release | deliverable | state |
|----|----|----|
| spike | easystats/`rms` capability matrix | [done](https://mufflyt.github.io/mysterymodel/inst/capability-matrix.md) |
| v0.1 | cohort contract, cleaning, profile, EDA, collinearity | [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md), the sample-size gate, [`mm_clean()`](https://mufflyt.github.io/mysterymodel/reference/mm_clean.md) and [`mm_eda()`](https://mufflyt.github.io/mysterymodel/reference/mm_eda.md) done; `mm_collinearity()` and `mm_univariate()` to come |
| v0.2 | `rms` modelling, nonlinearity, interaction, selection | [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md), [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md) done; selection to come |
| v0.3 | full-process validation, calibration, nomograms | [`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md) with full-process and clustered resampling, and [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md), done; imputation inside resampling and the flexible calibration curve to come |
| v0.4 | Quarto, scalable modes, provenance | planned |

`rms` is now an `Imports` rather than a plan, because the package fits
with it. `pROC` supplies the DeLong interval on the c-statistic and
`digest` the model fingerprint.
[`Hmisc::rcorr.cens()`](https://rdrr.io/pkg/Hmisc/man/rcorr.cens.html)
arrives free with `rms` and agrees with `pROC` on the estimate to 1e-14,
but its normal-approximation interval returns a figure where DeLong
correctly reports that none is estimable, so the dependency stays.

### What the spike settled

The architecture assumed `performance::model_performance()` could supply
general performance measures for the default model. It cannot. On an
[`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) fit:

- `insight::get_predicted()` returns `NULL`. easystats has no prediction
  path for `lrm`, so every prediction-dependent helper inherits that,
  and
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
  must call `rms` directly.
- `performance::model_performance()` returns only AIC, BIC, R2 and an
  RMSE it declares unreliable. No AUC, no Brier, no log-loss, so those
  come from `rms`, `pROC` and `yardstick`.
- `parameters::model_parameters()` agrees with
  [`coef()`](https://rdrr.io/r/stats/coef.html) exactly, to `0.00e+00`
  across all terms, and is safe to use.
- [`rms::vif()`](https://rdrr.io/pkg/rms/man/vif.html) and
  `performance::check_collinearity()` answer different questions,
  reporting 107.9 and 1.04 for the same spline. Both are correct;
  reporting either alone is misleading.
- `report::report()` and `modelbased::estimate_relation()` both error,
  for the same reason: they ask for predictions, receive nothing, and
  fail on the empty result. No adapter fixes that short of a prediction
  path.
- The usable shape is the consumer layer. `probably`, `dcurves`,
  `pointblank`, `GGally` and `correlation` all work, because they take a
  prediction vector or a data frame and never touch the fit. Compute
  with `rms`, then hand numbers onward.

The reference analysis is a labelled corrected successor, not an exact
reproduction of a legacy method
([DEC-001](https://mufflyt.github.io/mysterymodel/inst/decisions.md)).
Every function takes the `mm_` prefix, after the package name, in place
of the provisional `cp_` the specification carried
([DEC-002](https://mufflyt.github.io/mysterymodel/inst/decisions.md)).

## Citation

See
[`CITATION.cff`](https://mufflyt.github.io/mysterymodel/CITATION.cff),
or in R:

``` r

citation("mysterymodel")
```

## License

MIT. See
[LICENSE.md](https://mufflyt.github.io/mysterymodel/LICENSE.md).
