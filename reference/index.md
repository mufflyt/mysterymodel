# Package index

## Specify

What is being predicted, from which columns, and how the data divides.
Written down and checked before anything is fitted.

- [`cp_project()`](https://mufflyt.github.io/mysterymodel/reference/cp_project.md)
  : Create a validated analysis configuration

## Prepare

Eligibility with a ledger that reconciles, and a description that
carries its denominators.

- [`cp_clean()`](https://mufflyt.github.io/mysterymodel/reference/cp_clean.md)
  : Apply eligibility rules and account for every row that leaves
- [`cp_eda()`](https://mufflyt.github.io/mysterymodel/reference/cp_eda.md)
  : Describe the cohort, with denominators and missingness

## Fit and predict

The model, and risks from exactly that model.

- [`cp_model()`](https://mufflyt.github.io/mysterymodel/reference/cp_model.md)
  : Fit the declared model with rms
- [`cp_predict()`](https://mufflyt.github.io/mysterymodel/reference/cp_predict.md)
  : Predict risk from exactly the fitted model

## Validate

Performance on a stated basis, because apparent, bootstrap-corrected and
held-out numbers are not interchangeable.

- [`cp_validate()`](https://mufflyt.github.io/mysterymodel/reference/cp_validate.md)
  : Validate the model, on a stated basis

## Present

A nomogram that is checked against the model it was drawn from.

- [`cp_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/cp_nomogram.md)
  : Draw the nomogram, and prove it agrees with the model

## Data

- [`cp_synthetic_cohort()`](https://mufflyt.github.io/mysterymodel/reference/cp_synthetic_cohort.md)
  : Generate a synthetic cohort resembling a urodynamics study
