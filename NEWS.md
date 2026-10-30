# mysterymodel 0.0.0.9000

First development version; nothing is released yet. This records the history
by theme rather than by version. Each entry names the pull request that made
the change and, where a question had to be settled rather than merely
implemented, the record in `inst/decisions.md` that settled it.

## The pipeline

* `mm_project()`, `mm_clean()`, `mm_eda()`, `mm_model()`, `mm_predict()`,
  `mm_validate()`, `mm_nomogram()` and `mm_synthetic_cohort()` are the whole
  public surface. Everything else is internal (#1, #2, #3).
* The public prefix is `mm_` (#4, DEC-002).
* `mm_clean()` returns a ledger that reconciles. Rows in must equal rows out
  plus every exclusion, and a mismatch is an error rather than a note, because
  a cohort count that cannot be reconciled against the raw export is the
  commonest reason a published flow diagram does not add up (#2).
* `mm_eda()` carries the denominator each percentage is taken over and the
  missing count beside it, so a percentage computed over the complete rows
  cannot read as a fact about the cohort (#2).
* `mm_nomogram()` reads the drawn nomogram back the way a clinician reads it
  and refuses to return one that disagrees with `mm_predict()` (#3).
* Requires R 4.5 (#15). An exact patch-level dependency is not expressible:
  `R CMD check --as-cran` rejects `R (>= 4.5.2)`.

## Honest performance reporting

* `mm_validate()` returns one row per basis, because apparent,
  bootstrap-corrected and held-out numbers are not interchangeable and
  presenting one as another is the commonest way a published model flatters
  itself (#3).
* The fixed-model bootstrap is labelled as what `rms::validate()` does: it
  refits one formula and does not re-derive anything the formula was chosen
  by. `mm_full_process()` refits the whole strategy inside every resample and
  names what it re-executes (#3).
* Clustered resampling draws whole patients when the project declares a
  cluster, including inside `rms::validate()`, which takes a `cluster` through
  `predab.resample()`. Resampling rows under a clustered design narrows every
  interval it touches (#9).
* Resamples that `rms` could not fit are read off its `n` column and
  disclosed. Its own report of the shortfall is behind `pr`, which defaults
  off, so a corrected index could be an average over a self-selected subset
  with nothing on the object to say so (#9).
* Apparent calibration is withheld rather than printed as 0 and 1. Scoring an
  unpenalized fit on its own rows forces both, so they describe the estimator
  and not the model. The identity is detected rather than assumed, so a
  penalized fit keeps its estimate (#10).
* One scaled-Brier reference down the whole column, the development cohort's
  own, because a column of scores against different references is a comparison
  a reader will make and should not (#11).
* The c-statistic comes from the ROC and its bounds from the interval, which
  are two computations. Reading the estimate out of the middle of `ci.auc()`
  discarded a calculable c-statistic whenever DeLong could not be computed
  (#11).
* Every interval names its method and the event and non-event counts it rests
  on, in a new `non_events` column. An interval that cannot be computed is
  `NA` with the reason; one of zero width, which is what DeLong returns on
  complete separation or complete ties, says so rather than reading as
  precision; a limit truncated at the edge of the parameter space is named a
  bound. A corrected c-statistic carries no interval and says why: that needs
  a nested bootstrap, which is not implemented (#19, DEC-006).

## Refusing what cannot be meant

* A predictor that reproduces the outcome, or its exact complement, is refused
  by `mm_leakage()`. Separation that is not duplication is reported instead,
  because in a small cohort it can be real. A strong but non-deterministic
  association is not mentioned at all (#13, DEC-004).
* `mm_check_resamples()` refuses a fractional, missing, infinite or
  non-numeric resample count before any seed is set, rather than letting
  `as.integer()` turn 2.7 into 2 (#13, DEC-004).
* `mm_metrics()` refuses a predicted probability outside `[0, 1]` rather than
  clamping it, because a clamped 1.5 becomes a plausible Brier score (#13,
  DEC-004).
* Validating against a cohort that is not the one the model was fitted on is
  an error, checked by a hash of the modelling columns rather than a row
  count, and a reordering is refused too (#9).

## Counting the sample that exists

* Every reported count describes the rows `rms` fitted, not the rows it was
  handed. The sample-size gate judged the larger, partly imaginary sample,
  which made it most lenient exactly where data is most incomplete (#6).
* Which rows are modelled is decided once, before fitting, and the `datadist`,
  the fit and the prediction schema are all built from that frame. Left to
  `na.action` the three disagreed, and a value no fitted row carried came back
  labelled as interpolation while the drawn nomogram reached axis values the
  model was never estimated on (#7).
* `mm_evaluable()` is the one eligibility rule, read by fitting and by both
  kinds of validation. A missing predictor, a missing outcome and the overlap
  are counted apart, because taking a missing outcome for a non-event leaves
  the event count unchanged while inflating the denominator (#8, DEC-003).
* A factor level carried only by dropped rows is removed and named in
  `lost_levels`, since `rms` answers one with a singular Hessian that
  identifies neither the variable nor the level (#7).

## Patient data

* The model carries no copy of the cohort. A formula keeps the environment it
  was built in and `rms::lrm()` stores that on `fit$terms` and `fit$sformula`,
  so a model built the default way held the whole cohort, patient identifiers
  included, into anything that saved it. The formula is built in `baseenv()`
  (#5). The fitted model went from 176.5 KB to 36.1 KB and 500 planted
  identifiers to none, with the coefficient fingerprint unchanged.
* `mm_predict()` requires `newdata`, so no patient-level original is retained
  and no stored copy can drift from the data the caller has (#3).

## Tests

* 617 tests across 16 files, including 20 saboteurs that were each verified to
  fire against a deliberately disabled guard (#12), a leakage suite (#13), and
  a discrimination-interval suite that checks every degenerate case against an
  independent `pROC` call rather than a recorded number (#19).

## Simplification

* An audit for over-engineering produced thirteen findings; seven were
  implemented, one partly, and five retained on evidence (#16, #17, #18,
  DEC-005). `pROC` was kept because `Hmisc::rcorr.cens()` returns an interval
  where DeLong correctly reports that none is estimable, and the capability
  spike was kept because it still reproduces its matrix exactly. No reported
  number moved.
