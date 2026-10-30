# Decision log

Settled answers to the open questions in section 16 of the
[implementation specification](implementation-spec.md).

The specification is kept as received, because section 110 makes its hash part
of every artifact's provenance and amending it in place would quietly
invalidate that record. Decisions are recorded here instead and are binding on
implementation.

## DEC-001: the reference analysis is a labelled corrected successor

**Settles:** section 16, final bullet. **Date:** 2026-10-27.

The reference analysis does **not** reproduce the legacy methodology exactly.
It runs the analysis as the specification requires and is published as a
separately named analysis that makes no claim to be the original. The legacy
method is retained and run as a labelled comparator rather than deleted.

### Why

Reproducing the legacy method exactly would encode it as the specification.
Where the original does something the "Must not" list in section 15 forbids,
the reference path would need an exemption from the package's own gates, and
the package would ship a blessed route around them.

Keeping the legacy method as a comparator preserves what matters about exact
reproduction, which is the ability to see what each correction moved. Deleting
it leaves a reader unable to tell whether a changed estimate came from a fix
or from noise.

### Consequence for the fixtures

The two kinds of test assert different things and must not be conflated:

| fixture | asserts | when it changes |
|---|---|---|
| characterization | what the old code did, no claim it was right | a finding, to explain and record |
| reference | what the corrected analysis produces | a failure |

Freezing legacy numbers as a characterization test is what makes the
comparator honest: the suite documents the old behaviour without endorsing it.

### Precedent

`mufflyt/nomogram-final` does exactly this. The prior methodology is retained
as analysis A, unpenalized with year-blind imputation and complete-case
scoring, against a penalized primary analysis C, and the contrasts are
reported as attributable: B less A is the missing-data repair, C less B is the
penalization, C less D is the evaluated population.

### What this does not decide

Which corrections the legacy UDS analysis needs. That requires reading
`Elena.Rmd` and its verified outputs, which sections 84 and 237 both insist on
before any claim of equivalence. No defect is asserted here.

## DEC-002: the public prefix is `mm_`

**Settles:** section 16, first bullet, prefix half. **Date:** 2026-10-29.

Every exported and internal function takes the prefix `mm_`, after the package
name, in place of the `cp_` the specification carried as provisional. Class
names move with them: `mm_project`, `mm_cohort`, `mm_eda`, `mm_model`,
`mm_adequacy`, `mm_validation`, `mm_nomogram`.

### Why

`cp_` was shorthand for `clinpredict`, the alternate name section 3 keeps until
clearance. The package is `mysterymodel`, so `cp_` names a package that is not
this one, and a reader who meets `cp_validate()` has no way to guess which
library to attach. A prefix that is not the package name is a prefix that has to
be looked up.

`cp_` is also not ours to assume: it is short enough to collide with any other
package that reaches for the same two letters, and a collision between two
`cp_predict()` functions is resolved by whichever was attached last.

### Scope

A mechanical rename, with no change to any signature, return value, check or
number. The test suite is the evidence: it was renamed in the same pass and
passes unchanged otherwise, so nothing in the statistics moved.

### What this does not decide

Package name availability on CRAN, which is the other half of the same section
16 bullet and still open. `mm_` follows `mysterymodel`, so a forced rename of
the package would put this decision back on the table.

### Migration

None offered. There is no released version, no `0.1.0` tag and no reverse
dependency, so no caller exists to break. The prefix is settled now precisely
so that no caller ever has to be migrated.

## DEC-003: complete-case fitting is retained, and validation is made cohort-aware

**Settles:** finding 3 of the post-vignette review. **Date:** 2026-10-29.

A model may be fitted on the complete rows. The exclusions are reported
everywhere they apply, and validation is judged against the sample the model
was actually fitted on rather than the frame it was handed.

One rule, [mm_evaluable()], is read by fitting and by both kinds of validation,
so the development sample cannot be decided twice and differently.

### What each stage does

| stage | rule |
|---|---|
| fitting | the complete rows; `n_supplied`, `n_incomplete` and `incomplete_by` record what left |
| internal validation | resamples the fitted cohort only, never the supplied frame |
| external validation | scores the eligible rows, reporting total, scored, and exclusions split by cause |
| individual prediction | `on_missing = "stop"` unchanged |

### Why a missing outcome is counted apart from a missing predictor

They are different exclusions. A patient missing a predictor cannot be scored.
A patient missing the outcome can be scored but contributes nothing to a
performance estimate. Collapsing them hides which, and the specific error worth
preventing is the one where a missing outcome is quietly taken for a non-event:
that leaves the event count unchanged while inflating the denominator, so every
reported risk comes out low and nothing in the table looks wrong.

### Why prediction keeps refusing

The complete-case path belongs to validation, where the analyst is measuring a
model, and is written as an explicit selection of rows followed by an ordinary
call to [mm_predict()] at its own default. Prediction is the other case: a
clinician holding an incomplete record wants a number, and a number is exactly
what must be withheld. Relaxing the default to serve validation would have
spent the refusal that matters to serve the case that could select its own
rows.

### Why an unseen factor level is still refused rather than excluded

An external cohort carrying a category the model never saw is a real situation
and not a missing value. Excluding those patients silently would change the
evaluated population without saying so, and collapsing the level is a modelling
decision belonging to the analyst. The refusal makes them decide. Where the
decision is exclusion, [mm_clean()] is where it belongs, because there it
reaches the flow diagram.

### What this does not decide

Complete-case analysis is a computational strategy, not a guarantee of
unbiased estimates. Missingness may be informative, the more so in the small
clinical cohorts this package is for, so nothing here claims the exclusions
were ignorable; the reported notes say so in as many words. Multiple imputation
is the answer and remains unbuilt, as does the section 16 question of how to
package portable imputers for new individual predictions, which this decision
leaves open.

## Still open from section 16

- Final package name availability. The prefix half of this bullet is
  settled in DEC-002.
- Minimum supported R version and operating systems.
- Outcome families in v0.1. The specification recommends binary first.
- How to package portable imputers for new individual predictions.
- Whether a report may contain patient-level examples. The specification
  recommends synthetic examples by default.
- Accepted calibrated-risk interval method, and bootstrap CI calculation.
- Which scalable model-fitting backends to support. No unapproved default.
