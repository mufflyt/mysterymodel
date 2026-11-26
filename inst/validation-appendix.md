# Technical appendix: how this package is tested

A record of what has been checked, against what, and to what tolerance. It
exists so that a number this package reports can be traced to the thing that
witnessed it, and so that the limits of that witnessing are written down
rather than assumed.

Three kinds of evidence appear here, and they answer different questions.

| kind | question | weakness |
|---|---|---|
| the test suite | does the code do what it says on inputs it was given | a test written from the same misunderstanding as the code passes |
| mutation and saboteur testing | would a guard notice if it were broken | a guard may be unreachable, or a mutant equivalent |
| external validation | does an independent implementation get the same number | agreement with the engine this package calls is nearly a tautology |

The third is the only one that can catch a shared misunderstanding, which is
why most of the defects listed at the end were found there.

## 1. The test suite

`testthat`, 38 files, **399 test blocks containing 1926 assertions**, zero
failures and zero skips when run against the source tree. The package has 22
exported functions, 18 registered S3 methods and 93 internal `mm_` functions
across 20 source files.

Every count here is produced by `Rscript tools/measure-facts.R
--assertions`, which also reports whether this file and the README still state
the values it measures. That probe exists because the numbers in this
paragraph were wrong for weeks, in every component, and none of them sat
inside a test contract, so nothing failed. The figures they used to claim are
recorded in the header of that script rather than here, so that the probe does
not report its own cautionary tale as drift.

Measured, not carried forward. The figures are the
in-repository ones, because they are the stable measure of how much is
asserted: `R CMD check` runs the suite against the installed tree, where the
structural blocks that read `R/` and `_pkgdown.yml` cannot see them and skip.
Under check the same suite reports `FAIL 0 | WARN 7 | SKIP 4 | PASS 1908`, and
both numbers are correct for what they measure. Section 6 names which blocks
skip and why.

| file | blocks | assertions | what it holds |
|---|---|---|---|
| `test-calculator.R` | 29 | 184 | the front end: form, server, gauge, comparison rows, and the figures it may not show |
| `test-adversarial-defaults-and-ticks.R` | 9 | 172 | every guard of findings W-2, W-3 and W-4, tried wrong in both directions |
| `test-interactions.R` | 15 | 92 | the rank invariant, LR against an independent nested fit, candidate parsing |
| `test-discrimination-interval.R` | 11 | 88 | every degenerate c-statistic interval, against an independent `pROC` call |
| `test-recalibrate.R` | 13 | 88 | a = 0 and b = 1 on the development sample, order preserved, Rubin by hand |
| `test-metric-reporting.R` | 16 | 73 | one scaled-Brier reference, withheld identity calibration, refused inputs |
| `test-estimability-depth.R` | 11 | 72 | separation as a definition, complexity reporting, convergence |
| `test-saboteurs-2.R` | 21 | 70 | tampering with the plan, the screen, the drawn sheet |
| `test-baseline-and-scope.R` | 11 | 65 | declared baselines, tabulation outcomes, ordered factors, event direction |
| `test-accessors.R` | 11 | 64 | the eight generics, and the three that cannot delegate to `rms` |
| `test-resampling.R` | 5 | 61 | clustered draws, whole units, refused identifiers |
| `test-collinearity.R` | 9 | 59 | three diagnostics, and the spline whose own bases must not flag it |
| `test-validation.R` | 11 | 58 | the four bases, the resample floor, the Monte Carlo error |
| `test-eligibility.R` | 13 | 56 | one rule for fitting and scoring, exclusions counted apart |
| `test-nomogram.R` | 13 | 53 | the sheet against the model, read-back, and a quiet empty axis |
| `test-decision-curve.R` | 12 | 40 | `dcurves` agreement to 1e-12, and four patients done by hand |

Two habits run through it. Expected values are **computed independently in
the test** rather than recorded from a previous run, so a test fails when the
quantity changes rather than when the implementation does. And a test that
asserts a number also asserts the property that makes the number meaningful:
the nomogram tests assert agreement *and* that a tampered nomogram would
disagree.

## 2. Numerical fingerprinting

Every change presented as behaviour-preserving was held to a fingerprint
covering coefficients, linear predictors, each validation basis, nomogram
ticks and off-tick readings, adequacy, cohort ledgers, the random-number
state and all printed surfaces, compared at **tolerance zero**. Refactoring
that moved no number was required to move none; where a number was meant to
change, the comparison was narrowed to the surfaces that should not have and
the moved figure was named.

This is what caught the reading-error change being larger than intended and
confirmed the simplification work altered nothing: nine findings implemented
across three pull requests with every number identical at tolerance zero.

## 3. Mutation and saboteur testing

A guard nobody has tried to defeat is a comment. Guards are disabled one at a
time in a scratch clone and the suite must notice.

**Mutation runs.** 16 guards in the first round, then 7 on the interaction
screen, then 5 on the estimability layer. Results are recorded with the
survivors, because a survivor is information:

- *Equivalent mutants.* Reporting the claimed columns instead of the measured
  rank survived because that line is only reachable where `identifiable` is
  true, which means the two are equal by construction. No test can
  distinguish them and none should be contorted to.
- *Unreachable invariants.* Removing the same-cohort digest check inside
  `mm_interactions()` survived because both frames come from one derivation
  and cannot disagree in any reachable state. It is kept as an assertion
  against future divergence, commented as what it is.
- *A real gap.* Widening the separation test from its definition to require a
  half-unit gap survived, because every separated fixture had diverged to the
  boundary. That was a genuine untested sensitivity, and a unit test now pins
  the predicate with fitted values separated by 0.01.

**Saboteurs.** 41 blocks across two files, each breaking something on purpose
and asserting the safeguard notices, with a comment saying what a reader
would have believed had the guard been absent. Two were wrong when first
written and are recorded as such: one tampered with a value an axis pins as
length one, so `rep(length.out = 1)` returned the original and the sabotage
was a no-op; the other assumed a rank check on the supplied cohort would miss
aliasing, when `model.matrix()` drops incomplete rows itself.

## 3b. Recalibration, decision curves and collinearity

Three capabilities were ported from `nomogram-final`, the analysis repository
this package was extracted from. Each existed there because of a real failure,
and the port is documented in
`review/import-candidates-from-nomogram-final.md` with a per-function
reconciliation in `review/nomogram-port-function-inventory.csv`.

**What they are for.** `mm_validate()` reports a calibration intercept and
slope and had no way to act on them. That gap matters because a reader takes an
absolute probability off a nomogram's bottom axis or a calculator's figure, so a
bias on the log-odds scale is the error that reaches them, and discrimination
says nothing about it. In the source project the held-out c-statistic was
ordinary at 0.753 against 0.809 apparent, while the held-out calibration
intercept was +0.596 because the base rate had moved.

**The invariant that governs recalibration.** `a + b * lp` with `b > 0` is
monotone, so no two patients can change places and the c-statistic is unchanged
**by arithmetic rather than by luck**. The suite asserts it directly, comparing
`order()` before and after at three values of `b`. The consequence is the thing
to keep straight: a correction is not a remedy for a model that does not
discriminate, and a model recalibrated on a sample must not have its
performance on that same sample reported as validation.

`b` is tested against 1, not against 0. A slope correction of 1 is no
correction, so `b = 1` is the null that matters; `b = 0` would ask whether the
model discriminates at all, which is a different question.

**The anchor with a known answer.** A maximum-likelihood logistic fit is
calibrated on the sample that produced it by construction, so the apparent
intercept correction is exactly 0 and the apparent slope exactly 1. The suite
pins both to 1e-6. Drift there is an arithmetic error in the correction rather
than a finding about the model, which is what makes it the one case where the
right answer is known in advance.

**Pooling across imputations.** `mm_rubin()` carries the between-imputation
variance, `T = Ubar + (1 + 1/m) * B`. Omitting that term is invisible in the
wrong direction: the point estimate stays correct and only the interval is too
narrow, so an interval would be understated precisely because the missing data
had been handled properly. Imputations whose estimate or standard error is not
finite are dropped **and counted**, so one that failed to converge cannot
become a silent absence from `B`.

**Net benefit.** `mm_decision_curve()` agrees with `dcurves::dca()` to 1e-12 at
every threshold, including ties exactly on the threshold, and is also checked
against a four-patient fixture small enough to verify by hand. `dcurves` is a
test-time reference, not a dependency. Computing a decision curve is not the
same as being entitled to publish one: net benefit is an explicit trade of a
benefit against a harm and means nothing until the decision-maker, the action
and the two outcomes being traded are named.

**The per-variable gate, and why it is not the per-parameter one.**
`rms::vif()` is per model-matrix parameter, and the bases of one restricted
cubic spline are collinear with each other by construction. On an ordinary
model fitted with `nonlinear = "age"` the per-parameter figures are 14.4, 126.4
and 71.4 for the three `age` columns, so a check that gated on them would
refuse every spline model this package can fit. `mm_vif_check()` therefore
gates on Fox and Monette's generalized variance inflation factor per variable,
computed from the correlation matrix of the coefficient estimates, which puts
that same `age` term at 1.01 on the comparable scale while still printing the
per-parameter values beside it. `inst/capability-matrix.md` finding 3 stated
this requirement before any collinearity function existed to meet it, and the
first port of this module did not meet it.

**Collinearity, three ways.** Variance inflation is per parameter and blind to
a variable predictable from a combination of others while correlating strongly
with none; redundancy asks exactly that; the Spearman pair matrix names the
pair a human can act on. `mm_collinearity_report()` requires the cohort and
verifies it against the model's development fingerprint, because `mm_model()`
does not retain the rows it was fitted on and diagnostics computed on a
different frame of the same shape would read as though they described the fit.

**Mutation evidence.** Twelve mutations over the three modules, all DETECTED,
recorded in `review/mutation-evidence.csv` with the driver kept at
`review/mutation-campaign.py` so the run can be repeated. Two are worth naming:

- *MP06* rewrites the slope test to compare `b` against 0 instead of 1. The
  apparent-recalibration anchor catches it, because `b_p` collapses to about 0
  on a fit whose slope is exactly 1, which reads as "this model needs
  correcting" for a model that needs none.
- *MP08* drops the `(1 + 1/m)` inflation from Rubin's rules. The pooled
  standard error silently equals the within-imputation one.

*MP12 survived its first attempt, and the test was at fault rather than the
mutation.* The assertion was that the returned pairs equalled themselves in
sorted order, which is vacuous whenever the fixture's natural order is already
descending, and it was. `which(arr.ind = TRUE)` walks the lower triangle column
by column, so the fixture was rebuilt with a weak first pair and a strong last
pair; unsorted it reports 0.24 first, sorted it reports 0.98 first. With the
sort removed the test now fails on four assertions.

**What has no mutation coverage.** Internal-external cross-validation, the
TRIPOD+AI reporting checklist and model updating are staged in a draft pull
request and are not in this tree. Nothing in this section describes them.

## 4. External validation

Fourteen cohorts and reference examples from outside this package. Provenance, licences and checksums
are in `benchmarks.md`; the runnable comparison is
`data-raw/external_benchmark.R`.

Fourteen, and one distinction among them: `GermanCredit` arrives with
`caret`, which can be a declared `Suggests`, so its checks run on every build.
Everything else needs a network fetch or an undeclared package, so for those
the invariance runs on synthetic data and the external comparison is recorded
here instead.

| cohort | what it tests | agreement |
|---|---|---|
| `titanic3`, Harrell's case study | the whole pipeline on a published clinical example | coefficients, probabilities, deviance **0** against `rms`; `validate()` corrected C and slope exact |
| `MASS::birthwt` | the canonical Venables and Ripley example | **0** against `rms`, 1.6e-09 against `glm` |
| `pROC::aSAH` | the DeLong interval, the one figure computed here | C and both limits to **ten digits** against `pROC` |
| `MASS::bacteria` | clustered resampling on real repeated measures | clustered corrected C exact against `rms::validate(cluster=)`; 31 of 50 subjects drawn against a theoretical 31.6 |
| `MASS::Pima.tr`/`.te` | a genuine train/test split | held-out C, interval, slope, intercept and Brier to **ten digits** against a hand calculation |
| `datasets::esoph` | grouped binomial and ordered factors | **0** against `rms` when expanded; grouped and expanded `glm` agree to 2.9e-08 |
| `mlbench::SynthDiabetes`/`2` | impossible zeros kept against recoded as missing | ledger reconciles with `complete.cases` under both; recoding costs 52.9% of the cohort |
| `ISLR2::Default` | the event level of a factor outcome | textbook coefficients reproduced; probabilities 6.7e-10 |
| `ISLR2::Weekly` | factor coding and a year split | **0** against `glm`; held-out C by hand to ten digits |
| UCLA graduate admissions | published coefficients | 4.4e-06 against a 1e-04 tolerance set by the printing |
| IBM Telco churn | factors, splines, interactions, identifiers, nesting | `rcs` matches `splines::ns` on **deviance** with differing coefficients; Contract × tenure χ² identical to `glm`'s own likelihood ratio |
| `rms` `?validate.lrm` | the author's spline-by-factor example | 12 terms, coefficients, probabilities, deviance all **0**; corrected C, slope and intercept exact |
| `pminternal` | optimism correction by an independent implementation | corrected C, slope and intercept to **six decimals** given the same resamples |
| `caret::GermanCredit` | a one-hot design with every level kept | 61 columns spanning 48 dimensions, refused with the deficiency named |
| `NHANES::NHANES` | missingness and repeated subjects at scale | ledger reconciles with `complete.cases` on three predictor sets; `glm` to 5.7e-14 |
| `MASS::birthwt` nomogram | points read back against prediction | **2.22e-16** over 29 tick profiles; bound exactly 0 with no spline |
| `rms` `?nomogram` | a spline by a factor, and a spline by a spline | the first drawn and read back to **2.22e-16**; the second refused, and rms draws it only with `interact=` |

### Tolerances, and why they differ

- **Zero** is required against `rms` given the same formula, because this
  package calls `rms` and any difference would be a defect in the wrapping.
- **Optimiser tolerance**, around 1e-09, is accepted against `glm`, which
  reaches the same maximum by a different route.
- **The printing** sets the tolerance for published values: a coefficient
  given to five decimals cannot witness agreement to ten.
- **Monte Carlo error** sets it for resampled figures. Two bootstrap
  implementations agree exactly only when they draw the same resamples;
  otherwise the comparison is against the spread, which `pminternal` put at
  0.0024 in corrected C at B = 200.
- **Equivalent parameterisations** are compared on fitted probabilities,
  deviance and degrees of freedom, never on coefficients. `rcs` against `ns`,
  ordered against nominal, and a moved baseline all span the same space and
  must agree on everything except the coefficients.

### Nomogram-specific evidence

A nomogram is the one artifact a clinician reads by hand, so the checks are
about the printed instrument and not only the fit behind it.

* **Points consistency.** `mm_nomogram()` reconstructs risk by summing axis
  points and interpolating the printed linear-predictor axis, consulting no
  model object, and refuses to return if the result disagrees with
  `mm_predict()`. Measured at 2.22e-16 on `birthwt`, 2.22e-16 on Harrell's
  spline-by-factor example and about 1.7e-16 on three encodings of one
  predictor.
* **Two parameterisations, one sheet.** A nominal and an ordered encoding of
  the same four-level predictor allocate points identical to twelve decimal
  places, 100.000000000, 56.464148145, 13.616803512 and 0, while their
  coefficients differ entirely. This is why the comparison is on points and
  fitted probabilities rather than on coefficient names.
* **What cannot be drawn.** A block crossing two continuous predictors is
  refused before drawing. `rms`'s own example takes the route the refusal
  describes, `interact = list(age = c(20, 40, 60))`, and produces one axis per
  setting: `cholesterol (age=20)`, `cholesterol (age=40)`,
  `cholesterol (age=60)`.
* **Save and reload.** A fitted model written to disk and read back predicts
  identically to ten decimal places, in 6.1 KB, carrying no copy of the
  cohort.
* **Unsupported shapes.** `lsp()`, a piecewise-linear term, and `pol()`, a
  polynomial, are not expressible here; only `rcs()`. Harrell's published
  examples use both, so those terms entered linearly when his models were
  reproduced, and the difference is stated rather than absorbed.

### What the privacy guarantee costs

Six packages in the surrounding ecosystem cannot read a model fitted by this
one, and they all fail for the same reason, so it is one fact and not six
surprises.

`mm_model()` builds its formula in `baseenv()`. That is deliberate: a formula
keeps the environment it was built in, `rms::lrm()` stores that on
`fit$terms` and `fit$sformula`, and a model built the ordinary way therefore
carries the whole cohort, patient identifiers included, into anything that
saves it. Stripping it took a fitted model from 176.5 KB to 36.1 KB and 500
planted identifiers to none.

The cost is that every helper which recovers the data *from the fit* breaks.
`regplot`'s source shows the mechanism exactly:

```r
rawdata <- eval(dname, environment(formula(reg)))
```

| package | what fails | workaround |
|---|---|---|
| `insight` / `performance` / `report` / `modelbased` | no prediction path for `lrm` at all | none; predates this and is in the capability matrix |
| `emmeans` | "unable to reconstruct the data" | none found |
| `marginaleffects` | "unable to extract the data from model of class `lrm`" | none found |
| `effects` | `object 'dev' not found` | none found |
| `sjPlot` | "response variable(s) `.mm_y` could not be found" | none found |
| `DynNom` | `object 'form' not found` from `getdata.DN()` | **yes**: it takes `data`, and its predictions then agree exactly, linear predictors to 1.1e-16 and risks to 0 across 189 patients |
| `regplot` | `object 'form' not found`, with or without the plots that need a cohort | **no**: `regplot()` has no `data` argument |

`rms` itself is unaffected because it reads the stored `x` and `y` and the
`datadist` rather than rebuilding a frame, which is why `anova`, `validate`,
`contrast`, `Predict` and `nomogram` all work.

This is a trade and not a defect, and the direction is defensible for a
package whose models may be fitted on patient data: a saved model that cannot
carry identifiers is worth more than an interactive renderer that reads them.
It had not been written down, which is the part that was wrong.

### A trap worth naming

Four coefficient comparisons in this work were made **by position** across
models whose term order differed, and every apparent disagreement was the
comparison and not the package: 5.705 on `esoph`, 3.165 on its unordered
variant, 8.5e-02 on the Pima spline. A fifth stripped a factor's `class`
along with an attribute, turning a three-level predictor into a bare integer
that spent one degree of freedom, and `rms` and this package agreed exactly
on the corrupted column.

A sixth was a different mistake with the same shape: `DynNom` returns a
linear predictor and `mm_predict()` returns a probability, so comparing them
directly reported a difference of 2.171 where the agreement was exact. On the
logit scale it is 1.1e-16, and on the probability scale it is zero.

**Coefficients must be matched by name, classes checked, and the scale of
both sides established before anything is compared.** Four of these six
apparent disagreements were the comparison, and in every case the package was
right.

## 5. What the external cohorts found

Eight defects, none reachable from this package's own fixtures. Each is
recorded in `decisions.md` with its reasoning.

| found on | defect | why the fixtures missed it |
|---|---|---|
| `titanic3` | `mm_interactions()` tested each block against a baseline that already contained it | every interaction test used a project declaring no interactions |
| Pima | the same defect in `mm_splines()`: both arms identical, risk gap exactly 0 | every spline test used a project declaring no splines |
| UCLA | ordered factors refused unconditionally | `levels()` always returns character, so `is.numeric(levels(x))` is always false, and no fixture had an ordered factor |
| `ISLR2::Default` | the event inferred as `sort(labels)[2]`, reversing every coefficient while the c-statistic stayed identical | the synthetic outcome is 0/1, where 1 is unambiguously the event |
| IBM Telco | an identifier accepted as a predictor; a rank-deficient baseline reported as a block failure | no fixture carried an identifier or structurally nested categories |
| `caret::GermanCredit` | a singular Hessian blamed on separation when the cause was a rank-deficient design, which has a different fix | no fixture was one-hot encoded with its reference levels retained |
| three encodings of one predictor, drawn | a model with an ordered predictor could not be drawn at all: the between-tick scan read the axis values rather than the schema, and `rms` tabulates an ordered factor's levels as the numbers it scores them by, so 1, 2, 3, 4 looked continuous and was interpolated to 1.5 | ordered factors had only just been permitted, and no fixture drew one |
| `pminternal` | corrected figures printed to eight digits with their Monte Carlo error hidden by a fixed seed | the seed is pinned by design, so no run of the suite could show the variation |

The pattern is worth stating: four of the eight were cases where a *default*
was doing the deciding — a plan inherited through `NULL`, a sort order, a
pinned seed — and a fixture that never exercised the default could not see
it. The other three were shapes of data the fixtures do not contain: an
identifier column, structurally nested categories, and indicator columns that
keep every level.

German Credit is also the only external cohort whose tests run on every
build, because `caret` can be declared in `Suggests` and carries the data.
The others need a fetch or a package that is not a dependency, so what runs
in CI for them is the invariance on a synthetic cohort, and the comparison
itself is recorded rather than repeated.

## 6. What is not tested, and what cannot be

- **Imputation inside resampling** is not implemented, so the full-process
  bootstrap names it among the steps it does not re-execute.
- **Penalized fits** are unreachable: `mm_model()` has no penalty argument. A
  test pins that assumption so it fails if it changes, because a nested
  chi-square reference test does not apply to a penalty chosen on the same
  data.
- **Multiple imputation** is absent for the same reason, and a single
  completed dataset is not an imputation analysis.
- **An interval for a corrected c-statistic** is not available by this route
  and is reported as absent with the reason; it needs a nested bootstrap.
- **A clinician scoring two mutually exclusive axes** of a drawn nomogram
  cannot be caught by any check here, because it happens on paper. The
  exclusive groups are named in the output for whoever writes the caption.
- **Whether a predictor was measurable at the moment of prediction** is not
  checkable by comparing columns. The leakage scan says so.
- **Page legibility** of an exported nomogram is not reduced to a count; the
  file shows it better than any number computed here.
