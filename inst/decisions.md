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

## Still open from section 16

- Final package name availability, and whether `cp_` survives API review.
- Minimum supported R version and operating systems.
- Outcome families in v0.1. The specification recommends binary first.
- How to package portable imputers for new individual predictions.
- Whether a report may contain patient-level examples. The specification
  recommends synthetic examples by default.
- Accepted calibrated-risk interval method, and bootstrap CI calculation.
- Which scalable model-fitting backends to support. No unapproved default.
