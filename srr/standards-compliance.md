# mysterymodel and the rOpenSci statistical software standards

Assessment of 2026-11-22, against the General standards and four category
sets: Regression and Supervised Learning, Machine Learning, Exploratory Data
Analysis, and Probability Distributions.

**The package.** `mysterymodel` is an orchestration layer for clinical
prediction modelling. It fits nothing itself: `rms` does the regression,
internal validation, calibration and nomograms, `pmsampsize` answers the
sample-size question, `pROC` supplies the interval on the c-statistic. What the
package contributes is the workflow holding those together and a set of
methodological safeguards, which the README states as design commitments:
apparent, bootstrap-corrected and held-out performance are reported separately
rather than interchangeably, a predictor that carries the outcome is refused, an
interval states what it rests on or why there is none, and a nomogram must
reproduce the model it was drawn from before it is returned.

Eleven exported functions (`mm_project`, `mm_clean`, `mm_eda`, `mm_splines`,
`mm_interactions`, `mm_model`, `mm_validate`, `mm_nomogram`, `mm_predict`,
`mm_calculator`, `mm_synthetic_cohort`), nine registered print methods, 5,961
lines across 16 source files, and a test suite of **26 files, 312 blocks,
1,327 assertions, zero failures and zero skips** as measured for this
assessment.

**No srr tags exist yet.** This is a pre-implementation assessment: every
verdict below is my reading of the source against the standard text, not a
developer assertion. That distinction matters for how the proportions should be
read, and it is why the conservative denominator is used throughout.

## Compliance metrics, reported separately

**Revised 2026-11-22 under the remediation specification.** The first version of
this document reported one number per standards set, mixing standards that are
*satisfied* with standards that are *achievable*. That makes "95.8% Regression"
read as implementation completeness when it is applicability. The four measures
below are now computed separately from `srr/verdict-ledger.csv`.

| measure | value | meaning |
|---|---:|---|
| applicability | 213 / 254 | standards that apply to this package at all |
| **implementation completeness** | **131 / 213 = 61.5%** | applicable standards actually satisfied by code today |
| **test-verified completeness** | **81 / 213 = 38.0%** | satisfied *and* exercised by a named test file |
| unresolved | 82 / 213 | applicable and not satisfied: 80 achievable, 2 not viable |

The implemented figure rose from 122 to 131 when `R/accessors.R` landed. Nine
standards closed, not the seventeen first mapped to that work package:
`RE4.2` to `RE4.6`, `RE4.9`, `RE4.10`, `RE4.18` and `RE7.3`. Convergence
statistics (`RE4.7`), transformation accessors (`RE4.12`), the save-and-reload
examples (`ML4.7`, `ML5.2b`, `ML5.2c`) and the precision controls (`EA4.1`,
`EA5.3`) are still unwritten, so they stay missing.

The denominator is **213 applicable**, which is the 211 positive verdicts plus
the 2 negative ones: a negative verdict is applicable, it simply cannot be
satisfied within this design. The per-set proportions in the sections below are
**applicability**, not implementation, and are labelled as such.

**Verification is the weakest of the three and the honest number to quote.** A
standard counts as verified here only when the ledger names a test file that
exercises it. Fifty implemented standards have no named test, mostly the
documentation standards, where the evidence is prose and the ledger's
`evidence_file` points at README or `inst/`. Those are not defects, but neither
are they test-verified, and the gap between 57.3% and 33.8% is exactly that
distinction.

## Method, and how to check it

Verdicts are at the level of the individual standard identifier, including
sub-lettered ones (`G2.4a`, `ML3.0d`, `RE7.1a`), because each carries its own
requirement. That gives **254** standards: General 68, Machine Learning 90,
Regression 48, Exploratory Data Analysis 34, Probability Distributions 14. The
174 top-level items in `srr-standards.md` would be the wrong denominator, and
the instruction's own expectation of "roughly 70 General standards" matches 68
rather than the 40 top-level ones.

Every verdict is in **`srr/verdict-ledger.csv`**, one row per standard with its
set, subsection, verdict and whether a `Y` is already done or feasible. The
tables below are counted from that file. Coverage is checked rather than
assumed: 254 identifiers in the checklist, 254 assigned, none missing and none
invented.

**The proportion is `Y / (Y + N + NA)`**, counting not-applicable standards
against the package, as the instruction directs. For this package that
convention is the right one: the not-applicable calls here are my estimates,
not developer-asserted `@srrstatsNA` tags, which is exactly the condition the
instruction names for using it.

**Reading the verdicts.** `Y` means satisfied or clearly achievable within the
current architecture; the ledger says which. `N` means possible in principle
but it would make this a different package. `NA` means the concept has no
referent here.

**Two `N` verdicts in 254 is few, and I looked for more.** The reason is
structural rather than generous: this package's gaps are overwhelmingly of two
kinds, neither of which is `N`. Either the capability is named on the roadmap
and a few lines from the `rms` fit it already holds (feasible `Y`: 89 of the
211), or the concept belongs to an iterative-optimisation framework this
package is not (`NA`: 41). Where I was generous on a first pass I corrected it,
and those corrections are recorded at the end.

---

## General Standards

| subsection | Y | N | NA | total | proportion |
|---|---:|---:|---:|---:|---:|
| Documentation | 8 | 0 | 0 | 8 | 1.00 |
| Input Structures | 29 | 0 | 0 | 29 | 1.00 |
| Algorithms | 1 | 0 | 2 | 3 | 0.33 |
| Output Structures | 1 | 0 | 0 | 1 | 1.00 |
| Testing | 27 | 0 | 0 | 27 | 1.00 |
| **total** | **66** | **0** | **2** | **68** | **0.971** |

42 already done, 24 feasible.

### Key evidence and gaps

**Documentation is 8 of 8 already done, which is rare.** `G1.1` (is this novel
or a re-implementation) is answered by the capability spike: `inst/capability-matrix.md`
measured what `easystats`, `tidymodels`, `rms` and `mlr3` can each do for an
`rms::lrm()` fit, and the README states the finding that decided the
dependencies, that easystats has no prediction path for such a fit at all.
`G1.2` is the lifecycle badge plus a roadmap with per-release state. `G1.3`
(terminology) is the whole point of the "Which number are you reporting?"
article: four c-statistics from one fit, and what separates them. `G1.5` and
`G1.6` are unusually well served, because all four vignettes compute their own
numbers rather than describing them, and `inst/validation-appendix.md` records
what was checked against what, to what tolerance.

**Input Structures is 29 of 29**, 16 already done. `mm_project()` alone carries
30 `stop()` calls, and they are refusals of configurations that cannot be
meant rather than type checks: an outcome that is also a predictor, a repeated
predictor, temporal validation without a time field, a clustered design without
an identifier, an outcome that does not vary, a positive class that is not an
observed value, a non-whole seed. `G2.14` and its sub-standards are
`mm_predict(on_missing = c("stop", "na"))` plus `mm_clean()`'s treatment of a
rule that evaluates to `NA`, which excludes those rows under their own heading
on the stated grounds that treating unknown eligibility as eligible and as
ineligible are different studies. `G2.9` (diagnostics on lossy conversion) is
`lost_levels`, `reference_moved` and `incomplete_by` in the model object.

The 13 feasible ones are the generic type-conversion and tabular-form
standards (`G2.4b`, `G2.4c`, `G2.6`, `G2.7`, `G2.8`, `G2.10` to `G2.12`): the
package accepts a `data.frame` and nothing else today, and widening that is
mechanical.

**Testing is 27 of 27**, 16 already done, and this is the strongest section in
the assessment. 168 `expect_error` and 172 `expect_match` calls mean error
conditions are asserted by message text and not merely by class, which is
`G5.2`. `G5.4a` and `G5.4b` are already met twice over: the likelihood-ratio
statistic in `mm_interactions()` is computed from the deviance difference and
cross-checked against `rms::anova(test = "LR")` on every call, and the
c-statistic is checked against an independent `pROC` call with
`Hmisc::rcorr.cens()` agreeing to 1e-14. `G5.6` (parameter recovery) has
`mm_synthetic_cohort()` with known truth. `inst/validation-appendix.md` is
explicit that agreement with the engine the package calls "is nearly a
tautology", and names external validation as the only evidence that catches a
shared misunderstanding, which is a more honest statement of testing limits
than most packages make anywhere.

**The two `NA`s are `G3.1` and `G3.1a`**, covariance method selection. `rms`
computes the variance-covariance matrix and the package makes no choice about
how, so the standard's request for alternative methods is delegated rather
than refused.

**`G4.0` is already done and easy to miss**: `mm_nomogram()` writes PDF and PNG
to a caller-supplied `out_dir`, so this package does have file output, unlike
most model-fitting packages.

---

## Regression and Supervised Learning

| subsection | Y | N | NA | total | proportion |
|---|---:|---:|---:|---:|---:|
| Input data structures and validation | 6 | 0 | 0 | 6 | 1.00 |
| Pre-processing and Variable Transformation | 6 | 0 | 1 | 7 | 0.86 |
| Algorithms | 4 | 0 | 0 | 4 | 1.00 |
| Return Results | 19 | 0 | 0 | 19 | 1.00 |
| Documentation | 1 | 0 | 0 | 1 | 1.00 |
| Visualization | 3 | 0 | 1 | 4 | 0.75 |
| Testing | 7 | 0 | 0 | 7 | 1.00 |
| **total** | **46** | **0** | **2** | **48** | **0.958** |

20 already done, 26 feasible.

### Key evidence and gaps

**`RE1.0` is satisfied by not having a formula interface.** The standard asks
for one "unless reasons for not doing so are explicitly documented", and the
reason is the package's central design commitment: the analysis plan lives in
`mm_project()` so that a reviewer checks it against the protocol rather than
reconstructing it from whichever `mm_model()` call ran. A fit that overrides
the plan records the departure. The formula is built internally and kept on the
fit, so a formula interface could be added, but the documented reason is what
meets the standard.

**`RE4.1` is already done, which is unusual.** "Regression Software may enable
an ability to generate a model object without actually fitting values" is
`mm_project()`: a validated, printable specification object that no fitting has
touched. Most regression packages have nothing to point at here.

**`RE2.4b` is the package's reason for existing.** Perfect collinearity between
response and a predictor is detected by `R/leakage.R` and refused, because a
predictor that reproduces the outcome under another name used to fit happily
and report an apparent c-statistic of 1.0000, which reads as success. Perfect
separation is the deliberate exception: with four events it is as likely to be
a small sample as a mistake, so it warns and the fit proceeds.

**`RE4.11` and `RE4.15` are already done and go beyond the standard.**
`mm_validate()` returns a metrics table with one row per basis and columns
`basis`, `n`, `events`, `non_events`, `c_stat`, `c_lower`, `c_upper`,
`cal_intercept`, `cal_slope`, `brier`, `brier_ref`, `brier_scaled`, `note`.
Each row names the method behind its interval and the event and non-event
counts the interval rests on, and a row that cannot have an interval says why
instead of leaving a blank: the two bootstrap-corrected rows carry none because
DeLong describes an apparent c-statistic and a corrected one needs a nested
bootstrap that is not implemented. The apparent row withholds its calibration
slope because scoring an unpenalised fit on its own rows forces the slope to
one, so that number would describe the estimator rather than the model.

**The 26 feasible verdicts concentrate in Return Results, and they are one
piece of work.** `RE4.2` through `RE4.7`, `RE4.9`, `RE4.10`, `RE4.12` and
`RE4.18` ask for `coef()`, `confint()`, `formula()`, `nobs()`, `vcov()`,
convergence statistics, fitted values, residuals, transformation functions and
a `summary()` method. **The package defines no accessor methods at all**: the
only S3 methods registered are the nine `print` methods. Every one of these is
available from the `rms` fit already stored in `model$fit`, so each is a
delegating one-liner. This is the single largest and cheapest block of
follow-up work in the whole assessment, and the clearest gap between what the
package knows and what a caller can reach.

**Visualization is the other gap.** `RE6.0` through `RE6.2` want a default
`plot()` method showing fitted values. The package draws a nomogram, which is a
different and more demanding object, and verifies it reads back to agreement
with `mm_predict()` to machine precision, but there is no `plot.mm_model()`.
Feasible, since `rms` supplies the plot machinery. `RE6.3` is `NA`: no
forecasting.

**`RE2.3` is `NA`**: centring and scaling are `rms::datadist`'s job, and the
package re-derives it per resample rather than choosing a transformation.

**`RE7.0a` and `RE7.1` are already done in an unusual way**: the standard asks
for tests confirming the software can reject perfectly noiseless input, and
the leakage tests are exactly that, written because the failure had already
happened.

---

## Machine Learning

| subsection | Y | N | NA | total | proportion |
|---|---:|---:|---:|---:|---:|
| Input Data Specification | 16 | 0 | 0 | 16 | 1.00 |
| Pre-processing | 11 | 0 | 1 | 12 | 0.92 |
| Model and Algorithm Specification | 7 | 1 | 10 | 18 | 0.39 |
| Model Training | 5 | 0 | 8 | 13 | 0.38 |
| Model Output and Performance | 12 | 0 | 0 | 12 | 1.00 |
| Documentation | 3 | 0 | 0 | 3 | 1.00 |
| Testing | 12 | 0 | 4 | 16 | 0.75 |
| **total** | **66** | **1** | **23** | **90** | **0.733** |

39 already done, 27 feasible.

### Key evidence and gaps

**Four of seven subsections are at or near 1.00, which surprised me.** The
Machine Learning standards' first sections describe a workflow this package
genuinely has: a data specification stage, then a model specification stage
that produces an object without training, then a single training call, then
assessment implemented separately.

- `ML3.0` through `ML3.0d` map onto `mm_project()` exactly: specification as a
  distinct stage after input specification, a dedicated function that specifies
  without fitting, accepting the input-specification object, returning something
  directly trainable, with a defined class and a `print` method.
- `ML2.0` through `ML2.0b` map onto `mm_clean(rules = list(...))`: a dedicated
  parametrized pre-processing function returning an `mm_cohort` that goes
  straight to `mm_model()` and prints its own reconciliation.
- `ML4.0` is `mm_model()`, a unified single-function training interface.
- `ML5.3` and `ML5.4` are `mm_validate()`, assessment implemented distinctly
  from training and reporting discrimination, calibration intercept,
  calibration slope and Brier rather than one number.
- `ML1.8` (equal treatment of missing values across training and test) is met
  by complete-case fitting with every excluded row counted and attributed.

**The 23 `NA`s are concentrated in two subsections and have one cause.**
`ML3.4` through `ML3.7` and `ML4.1` through `ML4.6` ask about training rates,
search-space exploration algorithms, loss-function choice, gradient paths,
batch sizes, epochs, loss curves and GPU usage. `rms::lrm()` is maximum
likelihood: there is no training rate to document, no search space to explore
and no epoch to monitor. A package that fits by maximum likelihood has no
referent for the parts of this standard set that describe iterative
optimisation, and that is a property of the method rather than an omission.

**The one `N` is `ML3.1`**, which asks for both untrained and pre-trained
models. The untrained half is `mm_project()`. The pre-trained half, loading
someone else's fitted model and applying it, conflicts with the package's
premise that the plan and the fit are checked against each other; the
fingerprint machinery exists to detect exactly that substitution.

**The most interesting feasible verdict is `ML1.7a`**, multiple user-defined
ways to impute. The README names imputation inside resampling as the largest
gap in the package, `mm_full_process(refit = )` is the hook where a caller's
imputation would go so that it lands inside the optimism, and `held_fixed`
already names each data-dependent choice that was not re-executed. The
architecture is built for this standard and the work is not done.

---

## Exploratory Data Analysis

| subsection | Y | N | NA | total | proportion |
|---|---:|---:|---:|---:|---:|
| Documentation Standards | 4 | 0 | 0 | 4 | 1.00 |
| Input Data | 3 | 1 | 5 | 9 | 0.33 |
| Analytic Algorithms | 2 | 0 | 0 | 2 | 1.00 |
| Return Results / Output Data | 3 | 0 | 0 | 3 | 1.00 |
| Visualization and Summary Output | 9 | 0 | 0 | 9 | 1.00 |
| Testing | 7 | 0 | 0 | 7 | 1.00 |
| **total** | **28** | **1** | **5** | **34** | **0.824** |

21 already done, 7 feasible.

### Key evidence and gaps

**Visualization is 9 of 9, and it is the nomogram that earns it.** `EA5.0` and
`EA5.1` (legible presentation, font sizes, labelling) are met by a sheet sized
to the model rather than to a fixed page, with printed names taken from the
cohort's `Hmisc` labels and configurable axes. There is deliberately no
pagination, on the stated grounds that a nomogram split across sheets makes a
reader carry a running total between them. `EA5.4` (digits) and `EA5.2` (not
relying on default numeric print formatting) are met by the print methods.
`EA6.1` (testing graphical output) is met more strongly than the standard asks:
`mm_nomogram()` reads the drawn sheet back the way a clinician does, summing
points and interpolating the printed axis without consulting the fit, and
refuses to return if that disagrees with `mm_predict()`.

**`mm_eda()` is a real fit for `EA3.0` and `EA4.x`.** It describes the cohort
with the denominator each percentage is taken over and the missing count beside
it, because a percentage whose denominator quietly excludes missing rows reads
as a fact about the cohort when it is a fact about the complete rows. That is
the kind of summary `EA3.0` asks to be extractable, and it is returned as a
data frame rather than printed text.

**Input Data at 0.33 is what disqualifies this category**, and the reason is
structural. `EA2.2` through `EA2.3` and `EA2.5` concern index columns across
multiple tables and the conventions for matching them. This package has one
cohort table. `cluster_id` is an index column and `affirm`-style checks exist
around it, which is why `EA2.1` is feasible, but there is no multi-table
workflow for the join-by-index standards to apply to, so five are `NA`.
`EA2.4`, an explicit relational data class, is the one `N`: adopting one would
be a different package.

---

## Probability Distributions

| subsection | Y | N | NA | total | proportion |
|---|---:|---:|---:|---:|---:|
| Documentation | 1 | 0 | 0 | 1 | 1.00 |
| Packages for Representing Distributions | 0 | 0 | 1 | 1 | 0.00 |
| Algorithms | 2 | 0 | 5 | 7 | 0.29 |
| Testing | 2 | 0 | 3 | 5 | 0.40 |
| **total** | **5** | **0** | **9** | **14** | **0.357** |

0 already done, 5 feasible.

### Key evidence and gaps

**This category does not apply, and the assessment should say so plainly.**
Nine of fourteen standards are `NA` and none of the remaining five is already
done.

The package rests on distributional assumptions (a logistic link, the normal
approximation behind the DeLong interval) and could document them, which is why
`PD1.0` is feasible rather than not-applicable. `PD3.2` and `PD3.3`
(optimisation tolerance specified and convergence information returned) are
feasible and overlap `RE3.2` and `RE4.7`. `PD4.3` and `PD4.4` (compare
optimisation results against an alternative implementation) are nearly done
already, through the likelihood-ratio and `pROC` cross-checks.

Everything else has no referent. `PD2.0` asks the software to represent
probability distributions using a general representation package; this package
represents no distributions as objects. `PD3.0`, `PD3.1`, `PD3.4`, `PD3.5` and
`PD3.5a` concern analytic versus numeric manipulation of distributions and the
conditions under which integrals converge; there is no integration anywhere.
`PD4.0` through `PD4.2` test the numeric output of distribution functions,
which the package does not provide.

---

## Task 3: scope and category fit

### Is the package in scope?

| standards set | Y | total | Y / (Y + N + NA) | clears 50% |
|---|---:|---:|---:|:---:|
| General + Regression and Supervised Learning | 112 | 116 | **96.6%** | yes |
| General + Exploratory Data Analysis | 94 | 102 | **92.2%** | yes |
| General + Probability Distributions | 71 | 82 | **86.6%** | yes |
| General + Machine Learning | 132 | 158 | **83.5%** | yes |

All four clear the bar comfortably, and across all 254 standards the package
stands at **211 Y, 2 N, 41 NA, or 83.1%**. **The package is well within scope.**

Read the Probability Distributions row with care: it clears 50% only because
the General standards carry it. That category is at 35.7% on its own and
contributes almost nothing.

### Which single category fits best?

**Regression and Supervised Learning, at 95.8%, and the architecture is the
argument rather than the number.**

Six of its seven subsections are at 1.00 and the seventh at 0.86. More
tellingly, the sections that score full marks are the ones that describe what
this package is: input validation that refuses what cannot be meant, documented
pre-processing, convergence diagnostics, a return object carrying goodness of
fit with its interval and the counts that interval rests on, and tests that
confirm noiseless input is rejected. The package is built on `rms`, the
regression engine the standards' own references point to, and its reference
text is Harrell's *Regression Modeling Strategies*.

Its weakest area, the missing accessor methods, is the most mechanical
follow-up in this document, because the fitted `rms` object is already stored
in `model$fit` and each accessor is a delegating one-liner.

### Is any other category independently viable?

**Machine Learning is viable as a secondary category, at 73.3%, and this is
the assessment's least obvious finding.** The first impression is wrong: this
is not an ML package, and I expected a low score. But the Machine Learning
standards' early sections describe a staged workflow (specify data, specify
model without fitting, train in one call, assess separately) that
`mm_project()` → `mm_clean()` → `mm_model()` → `mm_validate()` implements
closely enough to score 1.00 on four of seven subsections, including all
sixteen Input Data Specification standards. What drags it to 0.733 is the two
subsections about iterative optimisation, which maximum likelihood has no
referent for.

Whether to claim it is a judgement call. It would be defensible, and the
held-out-plus-bootstrap validation story is genuinely what those standards ask
for. It would also invite a reviewer to ask about tuning and loss functions,
which this package deliberately does not do.

**Exploratory Data Analysis is not viable** despite 82.4%, and this is a case
where the proportion misleads. It scores well on documentation, visualization
and testing, which are strong everywhere in this package, while the subsection
that would make it an EDA package, Input Data, sits at 0.33 because there is
one table and no index-matching workflow. `mm_eda()` is one step in a modelling
pipeline, not the package's purpose.

**Probability Distributions is not viable** at 35.7%, with nothing already
done.

### Recommendation

Submit under **Regression and Supervised Learning**, as the primary and
probably only category. Mention the Machine Learning fit in the submission if a
secondary is wanted, with the honest framing that the workflow standards fit
and the optimisation standards do not apply.

The package is in an unusually good position for this review. Three things an
editor will notice immediately: the four articles compute their own numbers
rather than describing them, `inst/validation-appendix.md` states what was
checked against what and to what tolerance and names its own weakest form of
evidence, and `inst/decisions.md` records the settled methodological questions
with identifiers that the documentation cites. The standards work that remains
is mostly tagging what already exists.

---

## Ranked follow-up work, cheapest first

1. **Add the accessor methods.** `coef()`, `confint()`, `formula()`, `nobs()`,
   `vcov()`, `fitted()`, `residuals()` and `summary()` for `mm_model`, each
   delegating to `model$fit`. That is ten Regression standards (`RE4.2` to
   `RE4.7`, `RE4.9`, `RE4.10`, `RE4.12`, `RE4.18`) plus `RE7.3`, and it is the
   highest standards-per-line work available. The package currently registers
   only `print` methods.

2. **Write the `@srrstats` tags.** 211 Y verdicts, of which 122 are already
   satisfied by existing code, so most of this is citation rather than
   engineering. Run `srr::srr_stats_pre_submit()` after, and expect the first
   run to report a low percentage until the tags are in.

3. **Document what the output does not carry.** `mm_clean()` sets
   `row.names(out) <- NULL`, so case names do not survive into the cohort.
   `RE1.3a` asks for exactly that to be documented, and `RE7.2` asks for a test.

4. **Add `plot()` for `mm_model`.** `RE6.0` to `RE6.2` and `EA4.2`. `rms`
   supplies the machinery; the decision to make is what the default should show
   given that the nomogram is the package's real figure.

5. **Expose the convergence controls.** `RE3.1` to `RE3.3` and `PD3.2`:
   `rms::lrm()` takes `maxit` and `eps`, and `mm_model()` passes neither
   through nor documents their defaults.

6. **Widen the accepted input forms.** `G2.7`, `G2.8`, `G2.10` to `G2.12`: the
   package takes a `data.frame` and nothing else.

7. **Imputation inside resampling.** `ML1.7a`, `ML1.7b`, `G2.14c`, `RE2.2`.
   The README already names this as the largest gap and
   `mm_full_process(refit = )` is the hook for it. This is the one expensive
   item on the list, and the only one that is a methodological commitment
   rather than plumbing.

## Appendix: corrections made during this assessment

Recorded because a first pass that was wrong twice is worth disclosing.

**I assigned four Machine Learning pre-processing standards from the subsection
heading rather than the standard text, and they were wrong.** `ML2.3` is not
about dimension reduction; it asks that the values associated with all
transformations be recorded in the returned object, which `mm_model()` does
with knots, `datadist` and reference levels. `ML2.0a` and `ML2.0b` are already
done, not feasible, because `mm_clean()` returns an `mm_cohort` that goes
straight to `mm_model()` and has a print method. Correcting that subsection
moved Machine Learning from 0.700 to 0.733.

**I had `ML5.3` and `ML5.4` as feasible when both are already done**, because
`mm_validate()` is assessment implemented distinctly from training and it
reports four kinds of performance, not one.

**I checked `mm_predict(interval = TRUE)` before claiming `RE4.14` and
`RE4.15`**, rather than trusting the parameter name. It returns `.lower` and
`.upper` from the standard error of the linear predictor and documents, in the
parameter description, that this is an interval for the model's own estimate
and not for the person.

**The package's own documented test counts have drifted.**
`inst/validation-appendix.md` says 24 files, 271 blocks, 1,079 assertions; the
README says 25 files, 318 blocks, 1,301 assertions; the suite as run for this
assessment is 26 files, 312 blocks, 1,327 assertions. None is a defect in the
code, but `G1.5` and `G5.0` rest on documented figures matching the suite, so
they are worth a pass.
