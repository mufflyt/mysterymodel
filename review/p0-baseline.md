# P0 baseline verification

Commit `787ff39` · mysterymodel 0.0.0.9000 · R 4.5 · 2026-11-22

Required by the remediation specification before any implementation. Every row
below was produced by running code against the package, not read from the
previous assessment.

## Repository state

| item | verified value |
|---|---|
| HEAD | `787ff39` |
| branch | `docs/validation-appendix`, 1 ahead of origin |
| working tree | clean except untracked `srr/compliance-roadmap.md` |
| test suite | 26 files, 312 blocks, **1,327 assertions, 0 failures, 0 skips** |
| exports | 11 |
| registered S3 methods | 9, all `print` |

The package's own documented test counts disagree with the suite as run:
`inst/validation-appendix.md` says 24 files / 271 blocks / 1,079 assertions and
`README.md` says 25 / 318 / 1,301. Neither is a code defect, but `G1.5` and
`G5.0` rest on documented figures matching the suite.

## The fitted object (specification B1)

```
class(mm_model(...))  ->  "mm_model"          single class, no inheritance
class(model$fit)      ->  "lrm" "rms" "glm"
names(model)          ->  project fit datadist formula nonlinear interactions
                          knots n_dev events_dev n_supplied n_incomplete
                          incomplete_by lost_levels leakage eligibility
                          n_held adequacy schema fingerprint development
```

## What the underlying methods actually do

Four results here contradict the delegation plan in
`srr/compliance-roadmap.md`, which was written from the object's shape rather
than from running it. This is why B1 precedes B2.

| generic on `model$fit` | result | consequence for the method |
|---|---|---|
| `nobs()` | `400`, equal to `model$n_dev` | delegation safe; assert the equality in a test |
| `coef()` | named numeric | delegate |
| `vcov()` | matrix | delegate |
| `formula()` | identical to `model$formula` | return `model$formula`, no delegation needed |
| `fitted()` | **NULL** | **must not delegate.** `rms::lrm()` does not populate `fitted.values`; the sources are `predict(fit, type = "fitted")` on the response scale and `fit$linear.predictors` on the link scale |
| `confint()` | **error** | **no profile-likelihood interval exists.** It dispatches to `confint.glm`, prints "Waiting for profiling to be done...", then fails with `$ operator is invalid for atomic vectors` |
| `residuals()` | numeric | nine types work: `ordinary`, `li.shepherd`, `pearson`, `deviance`, `pseudo.dep`, `gof` return numeric; `score`, `partial`, `dfbeta` return matrices |
| `summary()` | `summary.rms` | reports **effect sizes**, not a model summary. A delegating `summary.mm_model` would return something a reader would misread |

### Finding P0-1: `confint()` on a mysterymodel fit errors today

A caller who reaches into `model$fit` and calls `stats::confint()` gets a
failure, not an interval. The specification's B3 forbids silently replacing a
profile-likelihood interval with a Wald one. Here there is nothing to replace:
the profile route does not work on an `lrm` object at all. The method therefore
computes Wald intervals from `vcov()` and must say so in its documentation,
naming the unavailability of the profile interval as the reason. That is a
documented choice rather than a silent substitution.

### Finding P0-2: the returned formula names an internal column

`model$formula` is `.mm_y ~ age + bmi + sex`. The response is the package's
internal recoded outcome, not the user's `event`. `formula.mm_model()` will
return this, so `RE1.1` and `RE1.3a` need to document that the response term is
a derived column and which user variable it came from.

### Finding P0-3: `fitted()` has no documented scale

Because `rms::lrm()` leaves `fitted.values` empty, any `fitted.mm_model()` has
to pick a scale explicitly. `RE4.9` and the specification's B3 both require the
scale to be stated. Response scale (predicted probability) is the right default
for a clinical prediction model, with the linear predictor available on request.

## Scope separation

The `autotest` failure under investigation in Workstream C occurred in
**`mysterynpi`**, a different repository with 123 exports. It is not evidence
about `mysterymodel` and is diagnosed separately in
`tests/autotest-diagnostics/`.
