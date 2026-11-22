# Specification: taking mysterymodel to full srr compliance

Companion to [`standards-compliance.md`](standards-compliance.md), which
assessed the package. This says how to close it. Written 2026-11-22 against
commit `787ff39`, 254 standards, 122 implemented.

## 1. What "100%" can and cannot mean

Three different numbers get called 100%, and only two of them are reachable.
Fixing the target first, because the work is ordered differently depending on
which one is meant.

| target | now | reachable | why |
|---|---:|:---:|---|
| every standard this package can meet, implemented and tagged | 122 / 211 | **yes** | this is the goal of this specification |
| `srr_stats_pre_submit()` reports no undocumented standard | 0 / 254 tagged | **yes** | 211 `@srrstats` plus 43 `@srrstatsNA` |
| `Y / (Y + N + NA)` reaching 1.00 | 0.480 | **no** | 41 not-applicable and 2 not-viable standards sit in the denominator permanently |

**The third is impossible by construction and should not be chased.** A
not-applicable verdict counts against the proportion under the assessment
convention used in the companion document, and no amount of work converts "this
concept has no referent here" into "complied with". The arithmetic ceiling is
211/254 = **0.831**, and the package's *potential* compliance is already there.
What sits at 0.480 is *implemented* compliance, and that is the number this
specification moves.

On rOpenSci's own applicable-standards convention the end state is
211/213 = **0.991**, the shortfall being the two standards named in section 6.

**Definition of done.** All 254 standards carry a tag; `srr_stats_pre_submit()`
reports every applicable standard documented with none missing; every
`@srrstats` tag names the function that satisfies the standard and what it does;
every `@srrstatsNA` tag carries a justification on its own line; the verdict
ledger agrees with the tags and a test enforces that.

## 2. Order of work, and why this order

Eighty-nine standards are achievable and unimplemented. They are not evenly
distributed: fifty-four of them fall out of six concrete pieces of work, and
the rest are tagging. The order below is by standards closed per line of code,
except that WP1 comes first because everything downstream reads better once the
model object is reachable through the ordinary generics.

| | work package | standards closed | cumulative implemented | size |
|---|---|---:|---:|---|
| | *starting point* | | 122 | |
| WP1 | Accessors, `summary()` and serialization | 17 | 139 | small |
| WP2 | A `plot()` method and its documentation | 4 | 143 | small |
| WP3 | Convergence controls exposed | 6 | 149 | small |
| WP4 | Input coercion layer | 17 | 166 | medium |
| WP5 | Test-suite additions | 25 | 191 | medium |
| WP6 | Scaling and computational documentation | 5 | 196 | small |
| WP7 | Imputation inside resampling | 6 | 202 | large |
| WP8 | Remaining features and documented transfers | 9 | **211** | medium |
| WP9 | Tagging all 254, including the refusals | 0 new | 211 | medium |

The counts are checked rather than estimated: every one of the 89 achievable
and unimplemented standards is assigned to exactly one package, none twice and
none left out, and the cumulative column reaches 211 because 122 + 89 = 211.
The per-package identifier lists are in the sections below and the full
assignment is reproducible from the ledger.

WP1 through WP6, WP8 and WP9 are plumbing and prose. WP7 is a methodological
commitment and is deliberately late.

---

## 3. WP1: accessor methods for `mm_model`

**Closes 17:** `RE4.2` through `RE4.7`, `RE4.9`, `RE4.10`, `RE4.12`, `RE4.18`,
`RE7.3`, `ML4.7`, `ML4.8a`, `ML5.2b`, `ML5.2c`, `EA4.1`, `EA5.3`. The three
Machine Learning ones are the save-and-reload standards, which a `summary()`
and a documented serialization example close together; `EA4.1` and `EA5.3` are
the numeric-precision and storage-mode parts of a column summary.

**The situation.** `NAMESPACE` registers nine methods and all nine are `print`.
The fitted `rms` object is already stored at `model$fit`, so every accessor the
standards ask for is a delegation away. A caller who wants a coefficient today
must reach into `model$fit` themselves, which means the package's own object is
less usable than the one it wraps.

**Write, in a new `R/accessors.R`:**

```r
coef.mm_model      <- function(object, ...) stats::coef(object$fit, ...)
vcov.mm_model      <- function(object, ...) stats::vcov(object$fit, ...)
formula.mm_model   <- function(x, ...) stats::formula(x$fit, ...)
nobs.mm_model      <- function(object, ...) object$n_dev
fitted.mm_model    <- function(object, ...) stats::fitted(object$fit, ...)
residuals.mm_model <- function(object, type = "deviance", ...)
                        stats::residuals(object$fit, type = type, ...)
confint.mm_model   <- function(object, parm, level = 0.95, ...) { ... }
summary.mm_model   <- function(object, ...) { ... }
```

Four of these need a decision rather than a delegation, and the decision is the
interesting part of this package:

- **`nobs()` must return the development row count, not `nrow(cohort)`.** The
  package's whole position is that apparent, corrected and held-out numbers
  describe different row sets. `object$n_dev` is the denominator the apparent
  metrics were computed over, and `summary()` should report `n_held` beside it
  rather than leaving a reader to assume one number covers both.
- **`residuals()` needs a `type` and documentation of what each means**
  (`RE4.10` asks for enough documentation to interpret them). Deviance
  residuals are the sensible default for a logistic fit.
- **`confint()` on an `rms` fit** is not `confint.glm`. Use the fit's own
  covariance matrix and say in the documentation that these are Wald intervals
  on the coefficient scale, which is a different thing from the DeLong interval
  `mm_validate()` reports on the c-statistic. A reader who conflates them will
  misreport the model.
- **`summary.mm_model()` must not shadow `rms::summary.rms`**, which reports
  effect sizes rather than a model summary. Either return a structure that
  names both, or document the difference prominently. This is the one place in
  WP1 where a careless delegation produces a misleading object.

**`RE4.12`** (transformation functions and their inverses) is the spline knots
and the `datadist`: expose them as an accessor rather than requiring a reader to
know where in the object they live.

**The check.** One test file asserting every generic returns the right shape,
that `nobs()` equals `n_dev` and not the supplied row count, and that
`confint()` and `vcov()` agree with each other on a known fit.

---

## 4. WP2: a `plot()` method

**Closes 4:** `RE6.0`, `RE6.1`, `RE6.2`, `EA5.0a`.

**The decision to make first.** This package's real figure is the nomogram, and
`mm_nomogram()` is not a `plot()` method because it does far more than draw:
it reads the sheet back and refuses to return on disagreement. Do not make
`plot.mm_model()` an alias for it. The standards want a diagnostic plot of
fitted values, which is a different job.

**Write `plot.mm_model(x, which = c("calibration", "fitted", "residuals"))`**
defaulting to calibration, because for a clinical prediction model the
calibration plot is the one a reader needs and the one `rms::calibrate()`
already supplies. `RE6.1` then requires documenting that the default plot is
dispatched on class, which it is.

**The honest caveat to document:** a calibration plot drawn from apparent
predictions flatters the model exactly as the apparent c-statistic does. The
method should default to the bootstrap-corrected curve when a validation object
is available and say which one it drew on the plot itself. Drawing the
apparent curve silently would reintroduce the error the package exists to
prevent.

---

## 5. WP3 through WP6: the remaining plumbing

### WP3: convergence controls

**Closes 6:** `RE3.1`, `RE3.2`, `RE3.3`, `PD3.2`, `PD3.3`, `ML4.5`.

`rms::lrm()` takes `maxit` and `eps`. `mm_model()` passes neither and documents
neither, so a non-converging fit cannot be retried with a longer leash. Add
both as arguments with the `rms` defaults stated in the documentation
(`RE3.2` asks for exactly that), keep the non-convergence diagnostic already at
`R/modeling_rms.R:476`, and make it suppressible while still recording the
failure in the returned object, which is what `RE3.1` asks and what `PD3.3`
asks again from the distributions side.

### WP4: input coercion

**Closes 17:** `G2.3b`, `G2.4`, `G2.4b`, `G2.4c`, `G2.4e`, `G2.6`, `G2.7`,
`G2.8`, `G2.10` through `G2.12`, `G2.16`, `EA2.1`, `EA2.6`, `ML1.1`, `ML1.1a`,
`ML1.1b`.

The package accepts a `data.frame` and nothing else. Accept `tbl_df` and
`data.table` by converting at the boundary, refuse a list column by name rather
than letting it reach a model matrix, strip attributes from classed vectors
before they dispatch somewhere unhelpful, and report what each conversion
costs. `G2.3b` is `match.arg`'s case-insensitive partial matching on the
character arguments that already use it.

There is a working implementation of this exact layer in `mysterynpi`'s
`R/input_structures.R` (`as_linkage_table()`, `read_name_column()`,
`reject_list_columns()`, `drop_vector_attributes()`, `check_scalar()`), written
against these same standards. Read it before writing a second one; in
particular it records a defect worth not repeating, that checking
`is.character()` before inspecting the class lets a classed character vector
through untouched.

### WP5: test-suite additions

**Closes 25**, the largest package: `G5.2a`, `G5.3`, `G5.6b`, `G5.8a`, `G5.9`,
`G5.9a`, `G5.9b`, `G5.10`, `G5.11`, `G5.11a`, `G5.12`, `RE7.0`, `RE7.1a`,
`RE7.2`, `EA6.0a`, `EA6.0e`, `ML7.1`, `ML7.2`, `ML7.3`, `ML7.3b`, `ML7.5`,
`ML7.11`, `ML7.11a`, `PD4.3`, `PD4.4`.

Three groups, and the first is the only one with substance:

1. **Noise susceptibility** (`G5.9`, `G5.9a`, `G5.9b`): add trivial noise to the
   synthetic cohort and assert the conclusions do not move, then repeat under
   several seeds. This package is well placed for it because
   `mm_synthetic_cohort(seed =)` already generates known truth.
2. **An extended-test lane** (`G5.10` through `G5.12`, `ML7.11`): a flag such as
   `MYSTERYMODEL_EXTENDED_TESTS`, with the larger bootstrap counts and any
   external cohort behind it, and a documented note saying what the flag turns
   on, what it needs and how long it takes.
3. **Edge and shape assertions** (`G5.8a` zero-length input, `G5.3` absence of
   unexpected missingness in returns, `EA6.0a` and `EA6.0e` column classes,
   `RE7.2` case names surviving).

`PD4.3` and `PD4.4` are nearly free: the likelihood-ratio cross-check against
`rms::anova(test = "LR")` and the c-statistic check against `pROC` already
exist, and these standards ask for exactly that comparison to be a test.

### WP6: scaling and computational documentation

**Closes 5:** `RE5.0`, `ML6.0`, `ML6.1`, `ML6.1a`, `PD1.0`.

A vignette section measuring how run time and memory grow with rows,
predictors and bootstrap count `B`. Bootstrap validation is the expensive part
and `B = 200` is the default, so the useful statement is what `B` costs per
hundred on a cohort of a given size. `PD1.0` is a paragraph citing the
distributional choices the package rests on: the logistic link, and the
normal approximation behind the DeLong interval.

---

## 6. WP7: imputation inside resampling, and the two refusals

**Closes 6:** `G2.14c`, `RE2.2`, `ML1.4`, `ML1.6b`, `ML1.7a`, `ML1.7b`.

This is the one expensive item, the one the README already names as the largest
gap, and the one where the standards and the package's convictions meet.

The architecture is ready: `mm_full_process(refit = )` re-executes a supplied
function per resample, so an imputation performed there is inside the optimism
rather than before it. `held_fixed` already names each data-dependent choice
that was *not* re-executed, computed from the call rather than asserted, after
an earlier version kept printing a claim that had stopped being true.

**What to build:** imputation as a function the caller supplies and the package
re-executes per resample, with multiple strategies offered (`ML1.7a`), the
precise steps recorded in the returned object (`ML1.7b`), and the imputation
counted in the flow the way exclusions already are.

**What to refuse, and to tag as refused rather than leave undone.** Imputation
performed once before resampling must not be offered as a convenience, even
though it is one line and every user will ask for it. Doing it once leaks, and
the leak flatters every number downstream, which is the package's own stated
reason for existing. The right answer to `G2.14c` here is a *conditional* yes:
imputation inside resampling, tagged; imputation before it, refused in the tag
with that reason.

**The two `N` verdicts stay `N`, and the specification records why rather than
treating them as debt.**

- **`ML3.1`** asks for pre-trained as well as untrained models. The untrained
  half is `mm_project()`. Accepting someone else's fitted model conflicts with
  the premise that the plan and the fit are checked against each other, and the
  `fingerprint` machinery exists to detect that substitution. Tag
  `@srrstatsNA` with that reasoning.
- **`EA2.4`** asks for an explicit relational data class. One cohort table, one
  index column; adopting a relational system would be a different package.

---

## 7. WP8: the remaining nine

**Closes 9:** `RE1.1` (document how the internally built formula becomes a
model matrix), `RE1.3` and `RE1.3a` (carry input attributes onto the output, and
document what is not carried: `mm_clean()` sets `row.names(out) <- NULL`, so
case names do not survive today and nothing says so), `RE2.4a` (collinearity
among predictors, which the roadmap already calls `mm_collinearity()`),
`ML1.5` (one function summarising the contents of the training and test sets,
which `mm_eda()` nearly is but does not do per split), `ML2.6` and `ML2.7`
(export the transformation functions and document how to reverse them),
`ML3.2` (apply a different model to the same specification object, which
`glmnet` and `glinternet` are named for but not wired to), and `ML5.4b`
(accept a caller's own performance metric in `mm_validate()`).

Two of these are more than plumbing. `RE2.4a` is a real diagnostic the roadmap
has promised since v0.1, and `ML3.2` means making the engine a parameter rather
than a constant, which touches `mm_model()`'s whole surface. Neither is hard,
but neither is a one-liner either.

## 8. WP9: tagging, and the three traps

**Closes:** nothing new, and yet it is the work that makes `srr` report
compliance. 211 `@srrstats` tags and 43 `@srrstatsNA` tags.

**Mechanics.** `srr::srr_stats_roxygen(category = c("regression", "ml", "eda",
"distributions"))` scaffolds the file. `@srrstatsNA` tags must live in a block
titled `NA_standards` or `srr` rejects them. Run
`srr::srr_stats_pre_submit()` after every batch, not at the end.

**Three traps, each one learned the expensive way in `mysterynpi`:**

1. **Do not write a generated justification.** A tag reading "implemented in
   this file; see the function documentation" passes `srr` and tells a reviewer
   nothing. Twenty-nine such tags were written there and had to be rewritten,
   and rewriting them exposed a standard that had been claimed and was not
   satisfied. Write what satisfies the standard, in the tag, the first time.
2. **Put the tag where the code is.** A tag in the wrong file sends a reviewer
   to code that does not contain the thing claimed.
3. **A verdict label of `NA` in a CSV is indistinguishable from a missing
   value.** `srr/verdict-ledger.csv` uses `NA` as a verdict; any reader must
   pass `na.strings = character(0)` and assert the column is complete. This is
   the package's own subject matter appearing in its own fixture.

**Add the drift gate.** One test that regenerates every verdict from the tags
in the source and fails on disagreement with the ledger, checks the ledger
covers the canonical checklist exactly, and skips when the source tree is
absent because `R CMD check` runs the suite against the installed package,
which has no `R/`. A structural test that passes in the repository and fails
the check is the worst shape such a test can take.

---

## 9. Sequencing and acceptance

| stage | packages | standards implemented | `srr` reports |
|---|---|---:|---|
| now | none | 122 | nothing tagged |
| A | WP1, WP2, WP3 | 149 | not yet run |
| B | WP4, WP5 | 191 | not yet run |
| C | WP6, WP8 | 205 | not yet run |
| D | WP9 on everything above | 205 | 205 complied, 43 N/A, 6 missing |
| E | WP7 and its tags | **211** | **211 complied, 43 N/A, none missing** |

Stage D before E on purpose: tagging 205 standards reveals overclaims before
the expensive package is built, and the six still missing at that point are
exactly WP7's, so the gap is legible rather than mysterious. In `mysterynpi` the overclaim surfaced only when the tag
text was written out.

**Acceptance, all four required:**

1. `srr::srr_stats_pre_submit()` reports every applicable standard documented,
   none missing.
2. `R CMD check` is `Status: OK`, vignettes built, run against the installed
   package.
3. The verdict ledger agrees with the tags, enforced by the gate from WP8.
4. No `@srrstats` tag carries a generated justification, and no `@srrstatsNA`
   tag is bare. Both are greppable, so both are checkable:
   `grep -r "implemented in this file" R/` returns nothing, and
   `grep -rE "@srrstatsNA \{[A-Za-z0-9.]+\}\s*$" R/` returns nothing.

**What this does not buy.** Full tagging is not a quality claim; it is a claim
that each standard has been considered and answered. The package's strongest
evidence is elsewhere and already written: four articles that compute their own
numbers, an appendix that names its own weakest form of evidence, and a
decision log the documentation cites. Section 7's traps exist because tagging
is the part of this work most easily done badly, and a badly tagged package
reads worse to a reviewer than an untagged one.
