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

`cp_project()` is implemented and tested. Everything else on this page is the plan.

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

project <- cp_project(
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
#> <cp_project: uds>
#>   outcome    event (event = 1)
#>   predictors 3: age, bmi, sex
#>   split      year < 2023 develops, the rest is held out
#>   cluster    pid
#>   seed       1978
```

`cp_project()` fails closed on configurations that cannot be meant, rather than letting them fail later as something harder to read. It implements the conditions the specification names: an outcome that is also a predictor (which reports perfect discrimination, and so reads as success), a repeated predictor, temporal validation without a time field, a clustered design without an ID column, an outcome that does not vary, a positive class that is not an observed value, and a non-whole seed.

## Roadmap

Releases and acceptance gates are defined in full in the [specification](inst/implementation-spec.md), section 12.

| release | deliverable | state |
|---|---|---|
| spike | easystats/`rms` capability matrix | [done](inst/capability-matrix.md) |
| v0.1 | cohort contract, cleaning, profile, EDA, collinearity | `cp_project()` done |
| v0.2 | `rms` modelling, nonlinearity, interaction, selection | planned |
| v0.3 | full-process validation, calibration, nomograms | planned |
| v0.4 | Quarto, scalable modes, provenance | planned |

### What the spike settled

The architecture assumed `performance::model_performance()` could supply general performance measures for the default model. It cannot. On an `rms::lrm()` fit:

- `insight::get_predicted()` returns `NULL`. easystats has no prediction path for `lrm`, so every prediction-dependent helper inherits that, and `cp_predict()` must call `rms` directly.
- `performance::model_performance()` returns only AIC, BIC, R2 and an RMSE it declares unreliable. No AUC, no Brier, no log-loss, so those come from `rms`, `pROC` and `yardstick`.
- `parameters::model_parameters()` agrees with `coef()` exactly, to `0.00e+00` across all terms, and is safe to use.
- `rms::vif()` and `performance::check_collinearity()` answer different questions, reporting 107.9 and 1.04 for the same spline. Both are correct; reporting either alone is misleading.
- `report::report()` and `modelbased::estimate_relation()` both error, for the same reason: they ask for predictions, receive nothing, and fail on the empty result. No adapter fixes that short of a prediction path.
- The usable shape is the consumer layer. `probably`, `dcurves`, `pointblank`, `GGally` and `correlation` all work, because they take a prediction vector or a data frame and never touch the fit. Compute with `rms`, then hand numbers onward.

The reference analysis is a labelled corrected successor, not an exact reproduction of a legacy method ([DEC-001](inst/decisions.md)).

## Citation

See [`CITATION.cff`](CITATION.cff), or in R:

```r
citation("mysterymodel")
```

## License

MIT. See [LICENSE.md](LICENSE.md).
