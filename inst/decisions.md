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

## DEC-004: invalid statistical input is refused, never corrected

**Settles:** the three defects found by the saboteur probing after PR #12.
**Date:** 2026-10-30.

Where an input cannot be what it claims to be, the package errors. It does not
clamp, truncate, or coerce it into something nearby.

| input | was | is |
|---|---|---|
| a predictor reproducing the outcome | fitted, apparent C of 1.0000 | refused |
| `B = 2.7` | two resamples | refused |
| a predicted probability of 1.5 | clamped, Brier of 0.18 | refused |

### Why refusing beats correcting

Each of the three had a silent correction available, and each correction
produced a number a reader would believe. That is the whole problem. A clamped
probability yields a plausible Brier score, a truncated `B` yields a plausible
bootstrap, and a duplicated outcome yields the best discrimination anyone has
ever reported. None of them looks wrong on the page, so the correction does
not protect the analysis; it protects the run from stopping, at the analysis's
expense.

A refusal costs an analyst a minute and tells them where to look. A correction
costs them a result they cannot reproduce and a reviewer's confidence.

### Why duplication blocks and separation does not

They are different findings. A column reproducing the outcome on every
eligible row is settled by arithmetic: no cohort makes that a prediction.
Perfect separation is not settled by anything the package can see. With four
events, a marker that happens to divide them is as likely to be a small sample
as a mistake, and refusing it would make the package useless for exactly the
rare-outcome studies it is for.

So duplication errors, separation warns, and a strong but non-deterministic
association is not mentioned at all, because a correlation is what a predictor
is for.

### Where the scan runs, and why not earlier

In [mm_model()], not [mm_project()]. The development frame does not exist
until after the split, after the complete-case eligibility of DEC-003, and
after a factor level carried only by excluded rows has been dropped. Scanning
the supplied cohort would answer a question about rows the model will never
see. [mm_full_process()] does not rescan a resample, because the declared
cohort has already been scanned and a resample is a subset of it.

### What this does not decide, and cannot

Whether a predictor was available when the prediction would be made. No
comparison of columns establishes the timing or the causal standing of a
variable, so a value recorded after the outcome, a treatment chosen because of
it, or a feature engineered from it can be weakly associated and still be
unusable. That remains the analyst's, and the documentation says so rather
than implying the check covers it.

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

## DEC-005: what the simplification audit removed, and what it did not

**Settles:** the disposition of the thirteen findings from the repo-wide audit
for over-engineering.
**Date:** 2026-10-30.

Nine findings were implemented and four were retained. The rule applied was
that a line earns its place by doing a necessary scientific, operational,
reproducibility or compatibility job, and that a smaller package which moves a
reported number has not been simplified but altered. Every accepted change was
held to a fingerprint covering coefficients, predictions, each validation
basis, nomogram ticks and readings, adequacy, ledgers, random-number state and
all eight printed surfaces, and every one of them is identical at tolerance
zero.

### The four retained, with the evidence

**`pROC` is kept.** The proposal was `Hmisc::rcorr.cens()`, already installed
because `rms` depends on it. On eight fixtures, typical, heavily tied,
perfectly separated, near 0.5, n = 4, and 1% events among 2000, the two agree
on the c-statistic to within 1e-14. They do not agree on its uncertainty:
`Hmisc` reports a normal approximation from the Somers' Dxy standard error and
`pROC` reports DeLong, and the interval widths differ by about a percent
typically and by a fifth at two events. The decisive case is one event, where
DeLong is undefined. `pROC` returns `NA` and [mm_metrics()] says the interval
needs at least two of each outcome, which is the disclosure PR #11 was written
to produce; `rcorr.cens()` returns 0.699 to 0.901. Manufacturing an interval
exactly where the package currently reports that none is estimable is a loss
of rigour that a removed dependency does not pay for. Changing the inferential
method remains available as its own proposal, with its own decision record.

**The capability spike is kept.** `data-raw/capability_spike.R` was re-run on
2026-10-30 under R 4.5.2 and rms 8.1.1, the versions in the matrix header, and
reproduced all 21 rows of `inst/capability-matrix.md` byte for byte apart from
the generation date. It is therefore the matrix's working provenance rather
than a spent script, and section 14 of the specification still rests on it.

**`mm_nomogram(fun_at = )` is kept.** It is a documented argument of an
exported function. No internal caller exercising it says nothing about who
depends on it, and the package has a version number that has not yet promised
anything.

**`mm_adequacy(shrinkage = )` is kept.** The target shrinkage is a
methodological assumption, not a constant: a study planning to a stricter
target needs a larger sample, and hardcoding 0.9 would decide that for the
analyst. The `target_shrinkage` field is kept with it, unread by the package,
because the requirement is meaningless beside the target it was computed
under and `reason` names that target only when the sample falls short.

**`mm_resample()` stays in its own file.** The move saves no lines, the
function is one idea with its own test file, and both the validation and the
worked-example articles exercise it on its own.

### What the nine changed

Three duplications became one definition each: profile construction for the
nomogram's two readings, which are compared with each other and so must be
built alike; the four-fifths resampling floor, a methodological judgement that
was written twice; and `rate * (1 - rate)`, written five times, now a helper
that still takes the rate as an argument because which rate goes in is the
whole question. Four arguments and fields nothing set or read were removed:
`require_outcome`, the `predictable` mask, `what`, and pmsampsize's required
EPP. The internal `%||%` went, base R having shipped it since 4.4.0. The
single-use closure guarding the random-number state was inlined, and the guard
is now tested against an existing state, an absent one, and an error raised
after seeding.

## DEC-006: an interval is reported with what it rests on, or not at all

**Settles:** how the c-statistic's uncertainty is disclosed, after the audit
of interval reporting that followed DEC-005's decision to keep `pROC`.
**Date:** 2026-10-30.

Keeping DeLong settled which method computes the interval. It did not settle
when the interval it returns is evidence. Four cases were found where the
table reported a figure that looked better than what produced it, and all four
are now annotated on the row rather than left to the reader to notice.

| case | what was printed | what is printed now |
|---|---|---|
| classes separate completely | `1.0000 (1.0000-1.0000)` | the same, plus zero width, estimator has no information left |
| every prediction ties | `0.5000 (0.5000-0.5000)` | the same, plus the same reason |
| a limit past 0 or 1 | silently truncated by `pROC` | the same, named as a bound and not an estimate |
| a corrected c-statistic | two blanks | the blanks, plus why no interval exists for one |

Nothing numerical moved. Every coefficient, metric, nomogram reading, ledger
and random-number draw is identical at tolerance zero; what changed is the
`note` column, a new `non_events` column, and the printed table.

### Why no minimum event count

The obvious guard is a threshold: warn below ten events, or below twenty. The
package has no evidence for any particular number, and a threshold invented
here would be quoted back as though it did. DeLong's standard error is
governed by the counts in the two classes, so each row states the method and
both counts instead, and the reader judges a three-event interval themselves.
A rule that fires on the structure of the answer, a width of zero or a limit
at the edge of the parameter space, needs no threshold and cannot be wrong.

### Why the corrected rows say more than nothing

DeLong describes an apparent c-statistic computed once on one sample. A
corrected index is an apparent one minus an average optimism, and neither
`rms::validate()` nor [mm_full_process()] returns the distribution of that
difference. A nested bootstrap, resampling the cohort and running the whole
correction inside each draw, is the recognised interval for it and costs `B`
times the correction; it is not implemented. Two blank columns beside a row
that does carry an interval invite the reader to carry it across, so the
blanks are annotated with the reason and the method that would fill them.

## DEC-007: the between-tick reading error is a bound, not a probe

**Settles:** what `reading_error` means, after it was found to understate
itself by factors of two to thirteen.
**Date:** 2026-10-30.

The figure was computed by varying one predictor at a time across the midpoint
of each gap between its ticks, with every other predictor sitting at its first
tabulated value, and documented as "the worst case for linear interpolation
across a curve". It was not. Three things compounded.

**Errors add across axes.** Total points are additive, so a patient off-tick
in age and in BMI carries both axes' interpolation errors. One predictor at a
time captures one summand of a sum.

**The corner it probed was arbitrary.** A risk error is
\eqn{|plogis(lp + bE) - plogis(lp)|}, largest where the logistic is steepest,
at a risk of one half. Holding the other predictors at their first tick puts
the probe wherever that corner happens to fall; on the README's own model the
probed profiles ran from a risk of 0.04 to 0.54.

**Interaction strata went unvisited.** An interaction with a factor gives a
continuous predictor a different points curve per level, and `rms` draws those
as separate axes. Measured on an `age:sex` fixture, the `age` error ran to
-0.046 in one stratum where the other reached only -0.006.

Across six fixtures the reported figure was exceeded by ordinary profiles by
2.0 to 13.6 times. On the model in the README it was 7.8 times: 0.000633
reported against a bound of 0.00494.

### Why a bound is computable without searching the joint space

The discrepancy decomposes exactly:

\deqn{lp_{nomogram} - lp_{model} = b \sum_j e_j(x_j)}

Each \eqn{e_j} is zero at its own axis's ticks, which is what the
tick-agreement check already establishes and which was confirmed numerically
at 1e-16, and a model with no spline has \eqn{e_j} identically zero on every
axis. Because the predictors are chosen independently, the extremes of the sum
are the sums of the extremes, so one scan per axis suffices and no search over
combinations is needed. The worst total then passes through the steepest part
of the logistic, \eqn{u = -\delta/2}, without asking whether a profile at that
risk also attains the worst points error, which is what makes the result a
bound rather than an estimate.

Against 3000 profiles drawn anywhere inside the printed axes, the bound holds
on every fixture and exceeds the worst observed reading by 1.05 to 1.47 times.

### What it is not

Interpolation only: not the clinician's eye on the page, not a total off the
drawn scale, which is counted separately as `off_axis`, and not a predictor
beyond the development range, which [mm_predict()] marks as `.extrapolated`.
It is numerical rather than analytic, each axis being scanned on a finite grid.
That slack measured about one part in a thousand, an order of magnitude below
the margin the bound already carries.

### Consequence for DEC-005

The new scan builds its frames per axis and per stratum, so it no longer
shares a profile builder with the tick-agreement check. `mm_profiles()`, added
by the simplification audit to serve both, had one caller left and has been
folded back into [mm_tick_profiles()]. The audit's reasoning was right when it
was written: the two callers then built the same shape and had to agree. They
no longer build the same shape.

## DEC-008: an interaction screen reports evidence and changes no model

**Settles:** what `mm_interactions()` does, how estimability is decided, and
which inferential claims it refuses to make.
**Date:** 2026-10-30.

Three activities are kept apart in the API because conflating them is how an
exploratory association becomes a clinical prediction rule: testing
prespecified blocks, screening for blocks, and validating a model that
contains one. This release implements only the first. Nothing it returns is a
model, no term is added to one, and a small p-value is not a reason to add it.

### Estimability is decided by rank, and never by a contingency table

The required invariant is structural and runs before anything is fitted. For
each candidate, the reduced and full design matrices are built with
[stats::model.matrix()] and their ranks taken from the singular values with a
relative tolerance, after scaling, so that a column in years and a column in
kilograms do not let units decide rank. A block is tested only when the rank
it adds equals the columns it adds. A block adding no dimension is reported
`not_estimable` with `NA` for the statistic and the p-value.

That the check cannot read the design matrix off a fitted object is the point.
Where a factor level occurs under only one level of its partner, the block is
a copy of a main effect, and `rms::lrm()` answers with a singular Hessian and
convergence code 2. The fit dies, so the candidate that most needs the check
is exactly the one a fit-based check never reaches.

The reduced model's own rank is reported beside each candidate. A reduced
model that is already deficient makes every difference taken against it
unreliable however healthy the increment looks, and a populated contingency
table does not prevent it: a relabelled factor leaves all cells occupied and
six columns spanning four dimensions.

### Sparsity is reported and is never decisive

An earlier draft of this work proposed refusing a block when a cell carried no
events. That was wrong, and measuring it showed why. A combination of twelve
rows and no events leaves the design matrix at **full rank**: the interaction
is identifiable, the likelihood is close to flat in that direction, and the
test returns a statistic of 5.3e-08 with a p-value of 0.9998. Refusing it
would refuse every cohort in which an interaction is real and small, which is
the regime this package is for. So the test is reported, with the counts
beside it and a note that a near-null result on these counts describes the
sparsity rather than the absence of an interaction.

The two failures are therefore separated: rank decides whether a test is
reported, and separation describes what a reported test rests on. Convergence
decides neither. `fit$fail` was `FALSE` for the sparse block above.

### The likelihood ratio is computed twice and checked

`rms::anova.rms()` has supported `test = "LR"` since before this package, and
the fits already retain `x` and `y`. The statistic is taken from the
difference in deviance between two fits whose development digests are checked
to match, and cross-checked against rms's own LR table on every call, with
`lr_agrees` recording the result. Agreement was exact on binary by binary
(3.107269 on 1 df), three-level by binary (6.732767 on 2 df) and spline by
binary (1.934498 on 3 df). A disagreement is reported as `disagreement` and
neither number is presented as the answer.

`test = "Wald"` is the joint test of the whole block from the same table,
which is two degrees of freedom for a three-level factor and three for a
spline. It is never the test of a single dummy coefficient, and it is labelled
as Wald rather than as a likelihood ratio, which is the error this corrects in
the README.

### What the interface deliberately omits

`mode`, `validation`, `B` and `seed` are not arguments. In a prespecified
release they would do nothing, and an argument that does nothing is the
speculative generalisation this package's audit removed elsewhere. They belong
with the screening and resampling that need them.

`minimum_support` is not an argument either. A threshold on events would be
invented here and quoted back as though the package had evidence for it, which
is the reasoning of DEC-006. The support diagnostics are always reported
instead, and estimability is structural.

### Penalization and multiple imputation

Both are refused by being unreachable rather than by a guard. `mm_model()` has
no penalty argument and the package has no imputation, so `mm_interactions()`
cannot meet either. A test pins both assumptions and fails if they change,
which is when the inferential restrictions have to be built: a nested
chi-square reference test does not apply to a penalized fit whose penalty was
chosen on the same data, and a single completed dataset is not an imputation
analysis.

### Fixed at the root

`mm_model()` accepted `c("age", "age")` and the same pair listed twice in
either order. A formula reduces the first to a main effect and keeps one copy
of the second, so both added no term while the parameter budget counted a
block the model did not contain. Both are now refused where every caller
routes through, not only in the new function.

## DEC-009: the plan lives in the project, and the sheet says what it cannot draw

**Settles:** where prespecified spline and interaction terms are recorded, and
what a nomogram does with an interaction it can and cannot represent.
**Date:** 2026-10-31.

### The plan belongs to the project

Section 78 of the specification asks the project configuration to carry the
prespecified spline and interaction terms. It did not. `nonlinear`,
`interactions` and `knots` were arguments to [mm_model()], so the thing a
reviewer is meant to check against a protocol lived in whichever fitting call
happened to run, which inverts the purpose [mm_project()] exists for.

They are now fields of the project, validated when the plan is written rather
than when something is fitted from it: a spline on a non-predictor, a block
missing a main effect, a predictor crossed with itself, a block listed twice
in either order, and fewer than three knots all fail at `mm_project()`.

[mm_model()] takes them when its own arguments are `NULL`. An argument that
differs from a declared plan still works and is recorded as a `departure` on
the returned object, warned about, and printed, because a fit whose shape
differs from the written plan is a finding rather than a detail.

**An unset field is unset, not a declaration of linearity.** An earlier draft
treated `nonlinear = NULL` on the project as a plan of straight lines, which
made every existing call a departure from a default nobody had chosen. A plan
can only be departed from once it has been written down. What fills the gap is
[mm_splines()], which shows what the allocation is worth before it is
committed to.

### What a nomogram can draw

An interaction reaches the drawn sheet as one axis per level of its
categorical partner, and the arithmetic is sound: [mm_nomogram_points()]
matches every value an axis holds fixed, so exactly one contributes and the
read-back agrees with the model to machine precision, measured at 2.8e-17 for
binary by binary, 5.6e-17 for a three-level factor and 1.1e-16 for a spline by
a factor.

Two continuous predictors have no levels to separate by. `rms::nomogram()`
would need one of them fixed at stated settings through its `interact`
argument, and would then draw a different instrument: one axis per setting,
correct only at those values. The package does not pass that argument, so the
error arrived from inside rms naming `interact=list(...)`, an argument the
analyst never used, with nothing about what to do. Such a block is now refused
before anything is drawn, by name, with the model left exactly as fitted and
the recommendation section 90 already makes: present it as a calculator rather
than reshape the model to fit a drawing. The model is sound, and
[mm_predict()] and [mm_validate()] work on it normally.

### The failure no check in this package can see

A clinician holding the printed sheet sees two axes both labelled `sex`, one
for each level of `prior_uti`, and nothing on the page stops them scoring
both. The agreement check cannot catch it, because it happens on paper. So the
mutually exclusive groups are named in the returned object and in what it
prints, with the axis each group is read on and the predictor that chooses
between them, for whoever writes the caption.

No threshold on page crowding is applied. Section 90 asks for a visually
overloaded flag, and a count of axes is a poor proxy for whether a drawn sheet
is legible, which the exported file shows better than any number computed
here. What is reported instead is the structural hazard, a group of axes among
which the reader must choose, and the axis and predictor counts beside it.

Nothing numerical moved: coefficients, predictions, every validation basis,
nomogram readings, adequacy, ledgers and random-number state are identical at
tolerance zero. The printed output of three objects changed.

## DEC-010: how a categorical predictor enters the model is part of the plan

**Settles:** which level a categorical predictor is measured against, and the
two kinds of data this package refuses rather than mis-fits.
**Date:** 2026-10-31.

### The baseline was set by a sort order

Under treatment contrasts a factor's first level is the comparison category
every other coefficient for that predictor is measured against. `factor()`
makes it the alphabetically first value, so in this package's own fixtures
`sex` was measured against `female` and `indication` against `incontinence`
because of the alphabet. That is a reporting decision, and it was being taken
by `sort()`.

Worse, it could move. [mm_model()] droplevels a level carried only by rows
eligibility excluded, and if that level happened to be first the baseline
shifted while the coefficient names did not: `indication=prolapse` read
-0.3533 in one fit and -0.3337 in another, the same term against two
different comparison categories. The level loss was already reported in
`lost_levels`; its consequence was not.

`reference` is now a field of [mm_project()], validated against the cohort
when the plan is written, and applied before the `datadist`, the fit and the
prediction schema so that all three agree which level leads. A nomogram axis
and `mm_predict()`'s refusal of an unseen level both read those, which is why
one place had to decide it.

It reparameterises the report and not the model. Every prediction, the
apparent discrimination and the deviance are identical with and without a
declared baseline, and a test asserts all three, because that equality is
what makes the feature safe to use.

A declared baseline that no eligible row carries is **refused, not replaced**.
Replacing it would measure every coefficient for that predictor against a
level nobody chose, under the names the plan asked for. An undeclared move is
still possible and is now reported, in the warning, in `reference_moved` and
on a `BASELINE` line when the model prints.

### Two kinds of data this package cannot model

Both were found by comparing against rms on datasets outside the package's
own fixtures, and both used to fail late or misleadingly.

**A tabulation is not an outcome.** `mm_project()` accepted `ncases` from
`datasets::esoph`, a column of event counts per group, because the column
takes more than one distinct value. `mm_model()` then advised setting
`positive_class`, and that advice would have **worked**: it would have fitted
a model of exactly that many events per group. A column with more than two
distinct non-missing values and no declared positive class is now refused when
the plan is written, and the message names the tabulation case specifically,
because expanding to one row per patient is the fix.

**An ordered factor cannot be fitted.** `rms::lrm()` refuses one with
non-numeric levels from inside `Design()`, advising a change to the global
contrast option, which rms's own documentation warns against relying on. The
refusal is now this package's, naming the predictor and the two routes that
work: drop the ordering for one parameter per level, or score the levels and
enter the column as numeric for a trend. Both are defensible and they answer
different questions, so neither is chosen here.

`rms::scored()` is rms's own machinery for an ordinal predictor and fits,
tests its own departure from linearity, draws a nomogram axis and validates,
but only when the ordered factor's levels are numeric; `esoph`'s "25-34" is
refused by `scored()` too. Supporting it would mean an `ordinal` field beside
`nonlinear`, and the scores for labelled categories are a clinical judgement
rather than a coercion. It is not implemented, and the refusal above will need
the third route added to it when it is.

## DEC-011: the external benchmark is split by what each part proves

**Settles:** how this package is checked against an independently published
logistic regression, and why UCLA's dataset is not vendored into it.
**Date:** 2026-10-31.

Everything this package had been validated against until now was either its
own synthetic cohort or `rms`, which is the engine it fits with. Agreeing with
rms is close to a tautology. A published worked example is the first reference
that is not another run of the same arithmetic.

The UCLA graduate admissions example supplies one: 400 applicants, a binary
admission outcome, GRE, GPA and a four-level institutional rank, with
coefficients printed to five decimal places.

### What it found

It found a defect committed an hour earlier. The guard refusing ordered
factors asked `is.numeric(levels(x))`. `levels()` always returns character, so
that test is permanently `FALSE` and the guard refused **every** ordered
factor, including those `rms::lrm()` fits perfectly well. rms accepts an
ordered factor whose level labels parse as numbers and spends a linear term in
the scores plus a departure per level above the second; it refuses only labels
that do not parse, such as `esoph`'s "25-34". UCLA's four-level rank is
exactly the case the broken guard rejected. The check now parses the labels.

### What it confirmed

| check | worst difference | tolerance |
|---|---|---|
| published coefficients, `glm` | 4.43e-06 | 1e-04 |
| published coefficients, this package | 3.95e-14 | 1e-06 |
| `glm` against `rms`, probabilities | 5.33e-15 | 1e-06 |
| `glm` against this package, probabilities | 5.33e-15 | 1e-06 |

The published tolerance is the printing and not the arithmetic: a coefficient
given to five decimals cannot witness agreement to ten.

Ordered against nominal, both full rank: identical fitted probabilities to
5.9e-15 and identical deviance at 458.51749248, on five parameters either way,
with coefficients that differ because the parameterisations do. A numeric
score spends one degree of freedom where the factor spends three, raises the
deviance to 459.44177, and changes the fitted probabilities, so it is reached
deliberately and never by accident. A baseline declared at rank 4 leaves every
probability and the deviance unchanged and returns the published -1.55146 as
+1.55146, which is the arithmetic that proves the relevel did what it says.

### Why the data is not vendored

Redistributing UCLA's teaching dataset under this package's licence would be a
claim about rights that cannot be checked from here, and 5.5 KB of convenience
does not justify it. A test gated on network access is no better, because it
would never run where it matters.

So the benchmark is split by what each part proves. Every invariance and
degree-of-freedom count is a property of the parameterisation rather than of
anyone's data, so those are tested on a synthetic four-level ordered factor in
`tests/testthat/test-ordered-predictors.R` and run on every build. They are
also what caught the defect above. Cross-engine agreement runs there too,
against `stats::glm()`, which ships with R and shares no code with rms, and is
therefore the independent implementation that the published values were
standing in for.

What genuinely needs the 400 rows is reproducing printed coefficients, and
that is a one-off confirmation rather than regression protection. It lives in
`data-raw/external_benchmark.R`, beside the capability spike, re-runnable by
anyone with network access, with its result recorded in the table above.

## DEC-012: what the external cohorts found that the fixtures could not

**Settles:** the record of validating against datasets from outside this
package, and the two defects only they exposed.
**Date:** 2026-10-31.

Four cohorts were worked through: `titanic3` from Harrell's case study,
`MASS::birthwt` from Venables and Ripley, `pROC::aSAH`, `MASS::bacteria`,
`MASS::Pima.tr`/`Pima.te`, `datasets::esoph`, and `mlbench::SynthDiabetes`
with its corrected variant. Agreement with the engine that owns each number
was exact everywhere it should be, and the record is in the commit history.
What matters here is what the fixtures could not have found.

### Both defects were the same defect, found twice

DEC-009 moved the prespecified spline and interaction terms onto
[mm_project()], and made [mm_model()] take them when its own argument is
`NULL`. Two functions build a *reduced* model by passing `NULL`, and both
silently began fitting the plan instead.

[mm_interactions()] tested each block against a baseline that already
contained it, so the block added no dimension and the rank invariant refused
it as inestimable. Found on `titanic3`, where rms reported the blocks fine and
this package reported `not_estimable` for both.

[mm_splines()] built its linear arm the same way, so a project declaring a
spline on the predicted being compared gave two identical arms and a largest
risk gap of exactly zero: the function reported that the degrees of freedom
made no difference, for every cohort whose plan had been written down. Found
on the Pima cohort, after the first.

Every interaction and spline test in the suite used a project that declared
nothing, which is why neither was caught. Both now strip the plan for their
internal fits, which is not an override and raises no departure, and both have
a regression test whose project declares the thing being compared.

### A guard that could never fire

The refusal of ordered factors asked `is.numeric(levels(x))`. `levels()`
always returns character, so the condition was permanently true and every
ordered factor was refused, including those `rms::lrm()` fits. Found on the
UCLA admissions rank variable, four levels, which DEC-011 records.

### What the fixtures were never going to show

`mlbench::SynthDiabetes` and `SynthDiabetes2` are the same 768 rows under two
preprocessing decisions: clinically impossible zeros kept as data, or recoded
as missing. The eligibility ledger reconciled with `complete.cases()` under
both, and the arithmetic is worth recording because it is the case this
package exists for. Recoding costs **52.9%** of the cohort when all eight
predictors are used, 405 rows to insulin alone; dropping insulin and triceps
costs 5.3%. The `triceps` coefficient moves by a factor of 8.8 and `pressure`
changes sign. None of that is a defect in anything, and all of it is invisible
unless the exclusions are counted and attributed, which is what the warning
and `incomplete_by` do.

A restricted cubic spline on glucose agreed with `rms::lrm()` given the same
formula to **zero** on coefficients, fitted probabilities and deviance, with
knots at 85, 109.2, 131 and 184 in both.

### A note on reading these comparisons

Four times in this work a coefficient comparison was made by position across
models whose term order differed, and each time the apparent disagreement was
the comparison and not the package: 5.705 on `esoph`, 3.165 on its unordered
variant, 8.5e-02 on the Pima spline. Coefficients must be matched by name.
`esoph` also lost its factor `class` to an attribute-stripping line, which
turned `pclass` into a bare integer and made a three-level predictor spend one
degree of freedom, agreeing exactly with rms on the corrupted column.
