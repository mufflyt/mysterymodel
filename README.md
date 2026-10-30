# mysterymodel

<!-- badges: start -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

An opinionated workflow for building clinical prediction models that survive peer review.

`mysterymodel` is not another modelling framework. The statistics are done by engines that already do them well. What this package contributes is the orchestration between them, and the methodological safeguards that are easy to skip and expensive to skip.

## Status

Early, and deliberately so. The [implementation specification](inst/implementation-spec.md) is the contract of record, kept as received; settled questions are amended in the [decision log](inst/decisions.md). Section 14 requires a capability spike before any production module, and that spike is done:
[**capability matrix for `rms` objects**](inst/capability-matrix.md).

The statistical spine of the §15 starting milestone now runs on synthetic data: `mm_project()` → `mm_model()` → `mm_predict()` → `mm_validate()` → `mm_nomogram()`, 193 tests, `R CMD check` clean. The data-preparation and reporting ends of that chain are not built yet; the roadmap below says which.

## Articles

Three, each on synthetic data, each showing its own numbers rather than describing them:

- [**From a raw export to a checked nomogram**](https://mufflyt.github.io/mysterymodel/articles/mysterymodel.html). The whole pipeline in the order it has to run.
- [**Which number are you reporting?**](https://mufflyt.github.io/mysterymodel/articles/validation.html). Four c-statistics from one fit, what separates them, and the one caution about comparing two of them to each other.
- [**Reading the nomogram back**](https://mufflyt.github.io/mysterymodel/articles/nomogram.html). The agreement check done by hand, including the clamped-interpolation error that reported 1.1% for a patient whose risk was 0.6%.

## The idea

Three ecosystems, each used for what it is best at:

| | role here |
|---|---|
| [**rms**](https://hbiostat.org/R/rms/) | regression, bootstrap internal validation, calibration, nomograms |
| [**easystats**](https://easystats.github.io/easystats/) | collinearity, assumption checks, parameters, interpretation, reporting |
| [**tidymodels**](https://www.tidymodels.org/) | resampling, feature-selection workflows, model comparison |

A fourth, [mlr3](https://mlr3.org/), is worth adding for computationally heavy work on large data.

### How they compare

Approximate; some capabilities need extension packages.

| Capability | easystats | tidymodels | rms | mlr3 |
|---|---|---|---|---|
| Data cleaning | strong | strong | limited | strong |
| EDA and descriptives | excellent | good | good | moderate |
| Collinearity diagnostics | excellent | good | limited | extensions |
| Feature selection | moderate | strong | moderate | excellent |
| Model development | good | excellent | excellent | excellent |
| Nonlinear effects | good | excellent | excellent | excellent |
| Interaction assessment | good | good | excellent | good |
| Internal validation | partial | excellent | excellent | excellent |
| Calibration | good | good | excellent | good |
| Nomograms | not native | not native | excellent | not native |
| Large-data workflows | limited | good | limited | strong |
| Quarto reporting | excellent | excellent | good | good |

`easystats` is an analysis and interpretation ecosystem. `tidymodels` and `mlr3` are model development and evaluation frameworks. `rms` is the one suited to a regression-based clinical prediction model intended for publication.

## Design commitments

These are the decisions that make the package opinionated. They are defaults, not locks.

- **Continuous predictors stay continuous.** Nonlinearity is assessed, not assumed away by categorising.
- **`rms::lrm()` is the default binary-outcome model**, with `glmnet` and `glinternet` as alternatives.
- **Interactions are prespecified** and tested by likelihood ratio. Data-driven interaction discovery is reported as exploratory, and labelled that way.
- **Selection and imputation happen inside resampling**, never once beforehand. Doing it once leaks, and the leak flatters every number downstream.
- **Validation reports discrimination, calibration intercept and slope, Brier score, bootstrap optimism, and intervals.** Not discrimination alone.
- **Nomograms use the native `rms` machinery**, with readable labels, configurable axes, and pagination when a model outgrows one page.
- **No model-selection decision is made for you, and none is hidden.**

The reference is Frank Harrell's *Regression Modeling Strategies*.

## Installation

```r
# install.packages("pak")
pak::pak("mufflyt/mysterymodel")
```

## Usage

The analysis plan is written down and checked before anything is fitted, so a reviewer can check it against the protocol rather than reconstruct it afterwards from whichever code happened to run.

```r
library(mysterymodel)

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

`mm_project()` fails closed on configurations that cannot be meant, rather than letting them fail later as something harder to read. It implements the conditions the specification names: an outcome that is also a predictor (which reports perfect discrimination, and so reads as success), a repeated predictor, temporal validation without a time field, a clustered design without an ID column, an outcome that does not vary, a positive class that is not an observed value, and a non-whole seed.

Eligibility is applied by named rule, and every row that leaves is attributed to the rule that excluded it:

```r
clean <- mm_clean(raw, rules = list(
  "aged 40 or over" = ~ age >= 40,
  "plausible BMI"   = ~ bmi >= 16 & bmi <= 55
))

clean
#> <mm_cohort>  300 in, 282 out, 18 excluded
#>      300  rows as supplied
#>      -10  aged 40 or over (did not meet the criterion)
#>      290  remaining
#>       -6  plausible BMI (did not meet the criterion)
#>      284  remaining
#>       -2  plausible BMI (criterion could not be determined for these rows)
#>      282  remaining
```

Rows in must equal rows out plus every exclusion, and `mm_clean()` errors rather than returning a cohort it cannot reconcile. A rule that evaluates to `NA` is not a pass: those rows are excluded under their own heading, because treating unknown eligibility as eligible and as ineligible are different studies and the difference belongs in the flow diagram.

`mm_eda()` then describes the cohort with the denominator each percentage is taken over and the missing count beside it, since a percentage whose denominator quietly excludes missing rows reads as a fact about the cohort when it is a fact about the rows that happened to be complete.

Then fit, validate and draw:

```r
model <- mm_model(project, cohort, nonlinear = "age",
                  interactions = list(c("prior_uti", "sex")))
#> Warning: the development sample may be too small for this model: 338 rows
#> is 582 short of the 920 a model of 7 parameter(s) needs at 10.1% prevalence
#> for 90% shrinkage.

model$adequacy
#> <mm_adequacy>  adequate: FALSE
#>   development 338 rows, 34 events (10.1%)
#>   parameters  7 non-intercept, 4.9 events each (description, not the criterion)
#>   shrinkage   0.697 expected, heuristic
#>   requires    920 rows, 93 events (Riley, from the fitted R2 of 0.138)

mm_validate(model, cohort, B = 200, full_process = TRUE)
#> <mm_validation>  full-process: TRUE
#>   apparent                 n=404 events=45 C=0.6647 (0.5749-0.7546)  slope=1.0000
#>   bootstrap, fixed model   n=404 events=45 C=0.5990                  slope=0.6779
#>   bootstrap, full process  n=404 events=45 C=0.6112                  slope=0.7256
#>   held out                 n=196 events=22 C=0.7858 (0.6770-0.8946)  slope=1.7370
#>   Full process re-derives knot placement, datadist, factor levels per resample; 200 of 200 valid.

mm_nomogram(model, out_dir = "figures")
#> <mm_nomogram>
#>   axes            age, bmi, sex (prior_uti=no), sex (prior_uti=yes)
#>   profiles checked 27 at tabulated ticks
#>   worst gap vs mm_predict() 1.67e-16 (tolerance 1e-06)
#>   off-tick reading error    0.000948 in risk, midway between ticks
```

Four things in that output are deliberate.

**A model too large for its sample says so.** The gate is the Riley requirement from `pmsampsize`, not the events-per-parameter rule, which is reported as description and labelled as such. Note the agreement between the two independent routes to the same conclusion: the heuristic shrinkage of 0.697 and the bootstrap-estimated calibration slope of 0.751 below. One circularity is disclosed rather than hidden, in `?mm_adequacy`: the requirement uses the fitted R-squared, so it answers whether this sample was adequate for the model it produced, not how large a sample should have been collected.

**Performance is reported per basis, never as one number.** The same model measured four ways, and the spread is the point.

The two bootstrap rows answer different questions. The fixed-model one, from `rms::validate()`, corrects the optimism of estimating coefficients for one formula. The full-process one refits the whole strategy inside every resample, so each resample gets its own spline knot placement, its own `datadist` and its own factor-level handling, all three being learned from data. It also states what it does **not** re-execute, which is imputation, selection and tuning, because the package does not do them yet and a strategy containing them would not be fully validated by it either.

They are different estimators with their own Monte Carlo error, so a small gap between them is not evidence of anything.

Resampling is by whole patient when the project declares a cluster. Resampling rows would treat two visits by one person as two independent facts, which narrows every interval it touches.

**Invalid input is refused, not corrected.** A predictor that reproduces the outcome under another name used to fit happily and report an apparent c-statistic of 1.0000; `B = 2.7` ran two resamples; a predicted probability of 1.5 was clamped into a plausible Brier score. Each is now an error, because each silent correction produced a number a reader would believe ([DEC-004](inst/decisions.md)). Perfect separation is the deliberate exception: with four events it is as likely to be a small sample as a mistake, so it warns and the model still fits.

**The nomogram is checked against the model, not assumed to match it.** `mm_nomogram()` reads the drawn nomogram back the way a clinician does, summing points and interpolating the printed axis without consulting the fit, then refuses to return if the result disagrees with `mm_predict()`. Agreement holds to machine precision at tabulated ticks across linear, spline and interaction models.

**The reading error between ticks is measured and reported.** A spline curves between printed ticks and linear interpolation across them does not, so an off-tick reading carries the axis's own resolution error. It is exactly zero for a model with no splines and about 0.001 to 0.005 in risk with them. That belongs to every printed nomogram and to the clinician reading it, so it is a stated number rather than an unexamined assumption.

## Roadmap

Releases and acceptance gates are defined in full in the [specification](inst/implementation-spec.md), section 12.

| release | deliverable | state |
|---|---|---|
| spike | easystats/`rms` capability matrix | [done](inst/capability-matrix.md) |
| v0.1 | cohort contract, cleaning, profile, EDA, collinearity | `mm_project()`, the sample-size gate, `mm_clean()` and `mm_eda()` done; `mm_collinearity()` and `mm_univariate()` to come |
| v0.2 | `rms` modelling, nonlinearity, interaction, selection | `mm_model()`, `mm_predict()` done; selection to come |
| v0.3 | full-process validation, calibration, nomograms | `mm_validate()` with full-process and clustered resampling, and `mm_nomogram()`, done; imputation inside resampling and the flexible calibration curve to come |
| v0.4 | Quarto, scalable modes, provenance | planned |

`rms` is now an `Imports` rather than a plan, because the package fits with it. `pROC` supplies the interval on the c-statistic and `digest` the model fingerprint.

### What the spike settled

The architecture assumed `performance::model_performance()` could supply general performance measures for the default model. It cannot. On an `rms::lrm()` fit:

- `insight::get_predicted()` returns `NULL`. easystats has no prediction path for `lrm`, so every prediction-dependent helper inherits that, and `mm_predict()` must call `rms` directly.
- `performance::model_performance()` returns only AIC, BIC, R2 and an RMSE it declares unreliable. No AUC, no Brier, no log-loss, so those come from `rms`, `pROC` and `yardstick`.
- `parameters::model_parameters()` agrees with `coef()` exactly, to `0.00e+00` across all terms, and is safe to use.
- `rms::vif()` and `performance::check_collinearity()` answer different questions, reporting 107.9 and 1.04 for the same spline. Both are correct; reporting either alone is misleading.
- `report::report()` and `modelbased::estimate_relation()` both error, for the same reason: they ask for predictions, receive nothing, and fail on the empty result. No adapter fixes that short of a prediction path.
- The usable shape is the consumer layer. `probably`, `dcurves`, `pointblank`, `GGally` and `correlation` all work, because they take a prediction vector or a data frame and never touch the fit. Compute with `rms`, then hand numbers onward.

The reference analysis is a labelled corrected successor, not an exact reproduction of a legacy method ([DEC-001](inst/decisions.md)). Every function takes the `mm_` prefix, after the package name, in place of the provisional `cp_` the specification carried ([DEC-002](inst/decisions.md)).

## Citation

See [`CITATION.cff`](CITATION.cff), or in R:

```r
citation("mysterymodel")
```

## License

MIT. See [LICENSE.md](LICENSE.md).
