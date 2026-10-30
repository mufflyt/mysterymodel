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

## Validate

Performance on a stated basis, because apparent, bootstrap-corrected and
held-out numbers are not interchangeable.

- [`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
  : Validate the model, on a stated basis

## Present

A nomogram that is checked against the model it was drawn from.

- [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
  : Draw the nomogram, and prove it agrees with the model

## Data

- [`mm_synthetic_cohort()`](https://mufflyt.github.io/mysterymodel/reference/mm_synthetic_cohort.md)
  : Generate a synthetic cohort resembling a urodynamics study
