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
