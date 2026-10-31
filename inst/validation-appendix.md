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

`testthat`, 24 files, **268 test blocks containing 1059 assertions**, zero
failures and zero skips. The package has 10 exported functions, 9 registered
print methods and 45 internal `mm_` functions across 15 source files.

| file | blocks | assertions | what it holds |
|---|---|---|---|
| `test-interactions.R` | 15 | 92 | the rank invariant, LR against an independent nested fit, candidate parsing |
| `test-discrimination-interval.R` | 11 | 88 | every degenerate c-statistic interval, against an independent `pROC` call |
| `test-metric-reporting.R` | 16 | 71 | one scaled-Brier reference, withheld identity calibration, refused inputs |
| `test-saboteurs-2.R` | 21 | 70 | tampering with the plan, the screen, the drawn sheet |
| `test-baseline-and-scope.R` | 11 | 65 | declared baselines, tabulation outcomes, ordered factors, event direction |
| `test-resampling.R` | 5 | 61 | clustered draws, whole units, refused identifiers |
| `test-validation.R` | 11 | 58 | the four bases, the resample floor, the Monte Carlo error |
| `test-eligibility.R` | 11 | 52 | one rule for fitting and scoring, exclusions counted apart |
| `test-plan-and-drawing.R` | 8 | 49 | the project's plan, departures, undrawable blocks, exclusive axes |
| `test-estimability-depth.R` | 8 | 48 | separation as a definition, complexity reporting, convergence |
| `test-splines.R` | 9 | 47 | both allocations, the adjusted reference, no p-value |
| `test-leakage.R` | 19 | 44 | duplication errors, separation warnings, association silence |
| `test-sample-size.R` | 13 | 41 | the fitted sample, not the supplied one |
| `test-saboteurs.R` | 20 | 36 | the original twenty, each verified against a disabled guard |
| `test-model-reference.R` | 16 | 35 | the schema a deployed model may receive |
| `test-bootstrap-fidelity.R` | 7 | 33 | the unit drawn, the resamples fitted, the cohort identity |
| `test-ordered-predictors.R` | 6 | 31 | ordered against nominal against scored, and the invariances |
| `test-project.R` | 11 | 23 | a plan that cannot be meant fails closed |
| `test-reading-error.R` | 6 | 22 | the between-tick bound, searched for counterexamples |
| `test-cleaning.R` | 11 | 18 | the ledger reconciles or errors |
| `test-nomogram.R` | 8 | 17 | agreement at ticks, tick profiles |
| `test-full-process.R` | 7 | 16 | what the strategy bootstrap re-executes |
| `test-eda.R` | 9 | 15 | denominators travel with percentages |
| `test-synthetic.R` | 7 | 15 | determinism, and the caller's random-number state |

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

## 4. External validation

Twelve cohorts from outside this package. Provenance, licences and checksums
are in `benchmarks.md`; the runnable comparison is
`data-raw/external_benchmark.R`.

Twelve cohorts, and one distinction among them: `GermanCredit` arrives with
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

### A trap worth naming

Four coefficient comparisons in this work were made **by position** across
models whose term order differed, and every apparent disagreement was the
comparison and not the package: 5.705 on `esoph`, 3.165 on its unordered
variant, 8.5e-02 on the Pima spline. A fifth stripped a factor's `class`
along with an attribute, turning a three-level predictor into a bare integer
that spent one degree of freedom, and `rms` and this package agreed exactly
on the corrupted column. **Coefficients must be matched by name, and classes
checked before anything is compared.**

## 5. What the external cohorts found

Seven defects, none reachable from this package's own fixtures. Each is
recorded in `decisions.md` with its reasoning.

| found on | defect | why the fixtures missed it |
|---|---|---|
| `titanic3` | `mm_interactions()` tested each block against a baseline that already contained it | every interaction test used a project declaring no interactions |
| Pima | the same defect in `mm_splines()`: both arms identical, risk gap exactly 0 | every spline test used a project declaring no splines |
| UCLA | ordered factors refused unconditionally | `levels()` always returns character, so `is.numeric(levels(x))` is always false, and no fixture had an ordered factor |
| `ISLR2::Default` | the event inferred as `sort(labels)[2]`, reversing every coefficient while the c-statistic stayed identical | the synthetic outcome is 0/1, where 1 is unambiguously the event |
| IBM Telco | an identifier accepted as a predictor; a rank-deficient baseline reported as a block failure | no fixture carried an identifier or structurally nested categories |
| `caret::GermanCredit` | a singular Hessian blamed on separation when the cause was a rank-deficient design, which has a different fix | no fixture was one-hot encoded with its reference levels retained |
| `pminternal` | corrected figures printed to eight digits with their Monte Carlo error hidden by a fixed seed | the seed is pinned by design, so no run of the suite could show the variation |

The pattern is worth stating: four of the seven were cases where a *default*
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
