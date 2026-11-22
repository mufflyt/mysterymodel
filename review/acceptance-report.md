# Acceptance report

Specification: *mysterymodel Statistical Standards, Automated Testing, and
Independent Code Review*, version 1.0.

| | |
|---|---|
| baseline commit | `787ff39` |
| commits produced | `f43884e`, `ae8d86a`, `cfff46c`, plus the commit carrying this report |
| package | mysterymodel 0.0.0.9000 |
| environment | R 4.5.2 (2025-10-31), aarch64-apple-darwin20 |
| tool versions | autotest 0.2.0.11, testthat 3.3.2, srr 1.1.0.9000, roxygen2 as installed |
| generated | 2026-11-22 |

**This report is incomplete by design, and says where.** Workstream E,
independent review, has not run. Specification rule 10 states the implementing
agent must not be the sole authority for accepting its own changes, and I am
that agent, so acceptance items 9 and 11 cannot be signed here.

## 1. The assessment before and after

The prior assessment reported one proportion per standards set. That number was
**applicability**, and reporting it alone let "95.8% Regression" read as
implementation completeness. The ledger now separates the three.

| measure | baseline `787ff39` | now |
|---|---:|---:|
| standards evaluated | 254 | 254 |
| applicable | 213 | 213 |
| **implementation completeness** | 122/213 = 57.3% | **131/213 = 61.5%** |
| **test-verified completeness** | 72/213 = 33.8% | **81/213 = 38.0%** |
| unresolved applicable | 91 | 82 |

`srr/verdict-ledger.csv` carries the required 13 fields, so applicability,
implementation status and verification status are now distinct columns rather
than one `state` string. Verification is asserted only where the ledger names a
test file; fifty implemented standards have no named test, which is the gap
between 61.5% and 38.0%.

**Category discipline.** Regression and Supervised Learning remains primary.
Machine Learning is retained as a supplementary assessment because its early
subsections genuinely describe this package's staged workflow, and its two
optimisation subsections are recorded as not applicable rather than failed.
Exploratory Data Analysis was **not** adopted on the strength of `mm_eda()`
existing: its Input Data subsection sits at 0.33 because there is one table and
no index-matching workflow, and the assessment says so. Probability
Distributions is assessed at 35.7% with nothing already implemented and is not
proposed.

## 2. What was implemented

**`R/accessors.R`**, nine standards closed: `RE4.2` to `RE4.6`, `RE4.9`,
`RE4.10`, `RE4.18`, `RE7.3`. Not the seventeen first mapped to that work
package; convergence statistics, transformation accessors, save-and-reload
examples and the precision controls remain missing and are recorded as such.

Three methods do not delegate, and P0 established why by running the generics
rather than reading the object:

| method | why it could not delegate |
|---|---|
| `fitted()` | `stats::fitted()` on an `rms::lrm()` fit returns `NULL`; `lrm()` leaves `fitted.values` empty |
| `confint()` | `stats::confint()` **errors**, dispatching to `confint.glm()`'s profiling, so no profile interval exists to preserve |
| `summary()` | `rms::summary()` reports effect sizes, not a model summary |

`confint.mm_model()` is Wald and documents that as a substitute with the broken
profile route named as the reason, which is what specification B3 requires
instead of a silent replacement. `summary.mm_model()` reports **no**
performance: discrimination, calibration and optimism come from
`mm_validate()`, and printing them beside coefficients would invite a reader to
treat an apparent number as a validated one.

`nobs()` returns the development row count after complete-case exclusion, and a
test asserts it equals the apparent `n` that `mm_validate()` used, so the
package's bookkeeping cannot drift from the fit.

## 3. Numerical validation evidence

| claim | evidence |
|---|---|
| `fitted()` introduced no second scoring path | `max abs(mm_predict - fitted) = 0` over 600 rows, exact rather than within tolerance |
| the two scales are one logistic apart | agreement to 1e-12 |
| Wald intervals are correct | recomputed in the test from `coef()` and `vcov()` independently of the implementation |
| intervals widen with coverage | 99% interval contains the 95% interval |
| the nomogram still reproduces its model | worst disagreement below its stated 1e-06 tolerance |
| the between-tick reading bound is derived, not sampled | `reading_error` below 1e-10 for a spline-free model, per DEC-007 |
| `mm_calculator()` agrees with the model | by construction: it scores through `mm_predict()` at `R/calculator.R:121` |

## 4. Tests added

| file | blocks | what it holds |
|---|---:|---|
| `tests/testthat/test-accessors.R` | 11 | the nine accessors, numerical agreement with `rms`, refusal of an unfitted object, and the three non-delegation reasons pinned so a future one-line "simplification" fails here |
| `tests/testthat/test-prediction-paths-agree.R` | 3 | Workstream D4 agreement across the prediction paths |

Suite: **28 files, 326 blocks, 1,398 assertions, 0 failures, 0 skips**, from
26 / 312 / 1,327 at baseline.

## 5. Findings

Nine, in `review/findings.csv`. By disposition: one open, three confirmed and
addressed, one partially addressed, two confirmed, one fixed, one unresolved.

**`D-1`, high, open on its substantive half.** The clinician-facing calculator
renders `95% CI x% to y%` beside a patient's risk with no caveat, while its own
documentation said no interval was shown because `mm_predict()` does not
produce one. Both halves of that sentence were false. The interval is the
standard error of the linear predictor on the probability scale, which
`mm_predict()` documents as being for the model's estimate **and not for the
person**: it excludes between-person variation and every model-selection
choice. A clinician will read it as the range the patient's risk lies in. The
false documentation is corrected; the displayed label is not changed, because
what a clinical calculator shows a clinician is a clinical-communication
decision and rule 4 reserves it for the owner.

**`R-1`, medium, open.** Handed an `mm_project`, `coef()`, `fitted()` and
`residuals()` return `NULL` and `summary()` returns a `summaryDefault`, while
`vcov()`, `nobs()`, `confint()` and `formula()` error. Silent `NULL` is what
this package refuses everywhere else. Closing it adds `mm_project` methods and
widens the public API, so it is the owner's call; today's behaviour is pinned
by a test so that a fix is a visible change rather than an accident.

**`C-2`, unresolved, and deliberately left so.** `autotest` fails
mysterynpi's enumeration, reproduced in a clean worktree at a single function
with `test = FALSE`. No mutation runs, so it is not evidence about any
package's input handling. A minimal package enumerates cleanly, so it is not a
blanket tool failure either. The evidence supports "enumeration fails on this
package" and does not yet support a statement about why, so no diagnosis is
recorded. Rule 3 forbids recording a failed tool as a pass; it equally forbids
recording a diagnosis the evidence has not earned.

## 6. Retractions

Recorded because the specification asks for an audit trail, and because a
report that hides its author's corrections is less useful than one that does
not.

1. **"A delegation away."** The remediation plan said every accessor the
   standards ask for was a one-line delegation. Three are not. Written from the
   object's shape instead of from running it, and corrected in place in
   `srr/remediation-plan.md`.
2. **The autotest narrowing.** An in-place bisect appeared to isolate the
   trigger to `check_scalar`'s signature. It was measuring leftover state:
   `autotest` leaves artefacts in the directory it runs in, and a baseline
   variant that had passed began failing once other variants had run there.
   Rebuilding fresh per variant made all of them pass. The narrowing is
   discarded, not reported, and the state leak is finding `C-1`.
3. **A premature classification.** Before any of the above, the autotest
   failure was described as "a bug inside autotest rather than a finding about
   mysterynpi". Neither half had evidence at the time: the minimal-package run
   later contradicted the first half, and the enumeration-stage finding is what
   supports the second.

## 7. Package health

| gate | result |
|---|---|
| unit tests | **28 files, 326 blocks, 1,398 passed, 0 failed, 0 skipped** |
| `R CMD check` | `Status: OK` verified on the tree carrying `R/accessors.R` and the namespace fix. **A re-run against the final committed tree was still in its test phase when this report was written and its status is not recorded here.** |
| documentation generation | `roxygenise()` clean; `mm_model-accessors.Rd` and `mm_calculator.Rd` regenerated |
| namespace and S3 registration | 18 `S3method()` entries, `importFrom(stats, ...)` declared in roxygen |
| synthetic end-to-end | `mm_project` to `mm_nomogram` exercised on synthetic cohorts throughout; no production research data touched by any test |
| ledger consistency | 254 identifiers, each with exactly one entry, verified programmatically |
| independent review | **not run** |

**A regression this gate caught.** The first `R CMD check` after the accessors
reported three WARNINGs and `object 'nobs' not found whilst loading namespace`:
`roxygenise()` had rewritten `NAMESPACE` and discarded `importFrom` lines added
by hand. The imports are now declared in a roxygen block where regeneration
keeps them. This is the second time in this work that a hand-edited `NAMESPACE`
was silently discarded, and it is the class of defect only the check finds.

**mysterynpi is a separate repository** and its continuous integration is not a
gate for this one. For the record, at the time of writing its `master` was
green on `downstream-consumers`, `pkgdown`, `test-coverage` and
`matching-gate`, with `R-CMD-check` not yet reporting a conclusion. That
pending result is stated as pending.

## 8. Acceptance checklist

| # | item | state |
|---|---|---|
| 1 | all 254 standards uniquely identified and traceable | **met** |
| 2 | applicability, implementation and verification reported separately | **met** |
| 3 | previously misclassified ML standards reassessed | **met**, with the ML2.x and ML5.x corrections recorded |
| 4 | each added S3 method agrees with the underlying documented behaviour | **met**, numerically |
| 5 | autotest failure reproducible and classified, or its limitation documented | **met as a documented limitation**; `C-2` is unresolved and says so |
| 6 | no exploratory test touched production research data | **met**: synthetic fixtures and disposable temp directories only |
| 7 | existing API and statistical results remain compatible | **met**: additive methods only, no existing signature or return structure changed |
| 8 | synthetic end-to-end modelling tests pass | **met** |
| 9 | all confirmed high-severity findings fixed and regression-tested | **not met**: `D-1` is high and its substantive half is open by design, awaiting an owner decision |
| 10 | `R CMD check` and CI gates verified, nothing pending shown as passed | **partially met**: `Status: OK` verified on the pre-commit tree; the re-run against the committed tree is pending and is reported as pending |
| 11 | final report with commits, evidence, unresolved issues and recomputed completeness | **this document**, with items 9 and 10 open |

**Release recommendation: do not merge yet.** Two items block it, and neither
is something I should close. `D-1` needs a clinical-communication decision about
what the calculator displays. Workstream E needs a reviewer who is not the
agent that wrote the code.
