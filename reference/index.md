# Package index

## Overview

What the package is for, the order the steps happen in, and what it
refuses to do quietly.

- [`mysterymodel`](https://mufflyt.github.io/mysterymodel/reference/mysterymodel-package.md)
  [`mysterymodel-package`](https://mufflyt.github.io/mysterymodel/reference/mysterymodel-package.md)
  : mysterymodel: Opinionated Workflow for Clinical Prediction Models

## Specify

What is being predicted, from which columns, and how the data divides.
Written down and checked before anything is fitted.

- [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md)
  : Create a validated analysis configuration

## Prepare

Eligibility with a ledger that reconciles, and a description that
carries its denominators.

- [`mm_clean()`](https://mufflyt.github.io/mysterymodel/reference/mm_clean.md)
  : Apply eligibility rules and account for every row that leaves
- [`mm_eda()`](https://mufflyt.github.io/mysterymodel/reference/mm_eda.md)
  : Describe the cohort, with denominators and missingness

## Fit and predict

The model, and risks from exactly that model.

- [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  : Fit the declared model with rms
- [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
  : Predict risk from exactly the fitted model

## Assess the shape

What a declared modelling decision amounts to: the degrees of freedom a
continuous predictor is given, and the evidence for a prespecified
interaction. Both report and decide nothing.

- [`mm_splines()`](https://mufflyt.github.io/mysterymodel/reference/mm_splines.md)
  : Draw each continuous predictor as a straight line and as a spline
- [`mm_interactions()`](https://mufflyt.github.io/mysterymodel/reference/mm_interactions.md)
  : Test prespecified interactions, and report what the test rests on

## Validate

Performance on a stated basis, because apparent, bootstrap-corrected and
held-out numbers are not interchangeable.

- [`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
  : Validate the model, on a stated basis

## Inspect the fit

The standard generics over a fitted model. Three cannot delegate to
`rms` and the documentation says which, and why.

- [`coef(`*`<mm_model>`*`)`](https://mufflyt.github.io/mysterymodel/reference/mm_model-accessors.md)
  [`vcov(`*`<mm_model>`*`)`](https://mufflyt.github.io/mysterymodel/reference/mm_model-accessors.md)
  [`formula(`*`<mm_model>`*`)`](https://mufflyt.github.io/mysterymodel/reference/mm_model-accessors.md)
  [`nobs(`*`<mm_model>`*`)`](https://mufflyt.github.io/mysterymodel/reference/mm_model-accessors.md)
  [`fitted(`*`<mm_model>`*`)`](https://mufflyt.github.io/mysterymodel/reference/mm_model-accessors.md)
  [`residuals(`*`<mm_model>`*`)`](https://mufflyt.github.io/mysterymodel/reference/mm_model-accessors.md)
  [`confint(`*`<mm_model>`*`)`](https://mufflyt.github.io/mysterymodel/reference/mm_model-accessors.md)
  [`summary(`*`<mm_model>`*`)`](https://mufflyt.github.io/mysterymodel/reference/mm_model-accessors.md)
  [`print(`*`<summary.mm_model>`*`)`](https://mufflyt.github.io/mysterymodel/reference/mm_model-accessors.md)
  : Standard accessors for a fitted mysterymodel

## Recalibrate

Correcting what a model says about the LEVEL of risk, which is the error
a reader of an absolute probability actually meets. A correction is
monotone, so it reorders nobody and cannot repair discrimination.

- [`mm_recal_intercept()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_intercept.md)
  : Fit an intercept correction on a recalibration sample
- [`mm_recal_slope()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_slope.md)
  : Fit the two-parameter correction, a + b \* lp
- [`mm_recal_apply()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_apply.md)
  : Apply a correction to linear predictors
- [`mm_recal_by()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_by.md)
  : Per-stratum intercept corrections
- [`mm_recal_mi()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_mi.md)
  : Estimate a correction on each imputation and pool it
- [`mm_rubin()`](https://mufflyt.github.io/mysterymodel/reference/mm_rubin.md)
  : Combine one scalar estimate across imputations by Rubin's rules

## Clinical utility

Net benefit across the thresholds a reader might hold. Computing the
curve is not authorisation to publish one.

- [`mm_decision_curve()`](https://mufflyt.github.io/mysterymodel/reference/mm_decision_curve.md)
  : Net benefit across treatment thresholds

## Collinearity

Three questions, because each misses what the others catch. The verdict
is per variable; the per-parameter detail is reported beside it, since
one spline’s bases are collinear with each other by construction.

- [`mm_collinearity_report()`](https://mufflyt.github.io/mysterymodel/reference/mm_collinearity_report.md)
  : All three collinearity diagnostics on a fitted model
- [`mm_vif_check()`](https://mufflyt.github.io/mysterymodel/reference/mm_vif_check.md)
  : Variance inflation, per variable and per parameter
- [`mm_redun_check()`](https://mufflyt.github.io/mysterymodel/reference/mm_redun_check.md)
  : Which variables are predictable from the others
- [`mm_cor_pairs()`](https://mufflyt.github.io/mysterymodel/reference/mm_cor_pairs.md)
  : The strongly correlated numeric pairs, for a human to look at

## Present

A nomogram that is checked against the model it was drawn from, and a
calculator built from the model’s own prediction schema.

- [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
  : Draw the nomogram, and prove it agrees with the model
- [`mm_calculator()`](https://mufflyt.github.io/mysterymodel/reference/mm_calculator.md)
  : A calculator for exactly this fitted model

## Data

- [`mm_synthetic_cohort()`](https://mufflyt.github.io/mysterymodel/reference/mm_synthetic_cohort.md)
  : Generate a synthetic cohort resembling a urodynamics study
