# What mysterymodel can take from nomogram-final

Source: `github.com/mufflyt/nomogram-final`, read at a shallow clone on
2026-11-22. That repository is mysterymodel's ancestor: same `mm_` prefix, same
comment voice, and several files are recognisably the un-packaged form of code
that is now in `R/`. Most of what is worth taking therefore ports with small,
mechanical changes rather than a rewrite.

The two repositories are not the same kind of thing, and that governs every
recommendation below. nomogram-final is an analysis repository: 154 R files,
101 test files, an `output/` tree, REDCap loaders, a manuscript. mysterymodel
is a package: 17 files in `R/`, 11 exports, 35 test files, `R CMD check`
`Status: OK`. Taking an analysis repository's scaffolding wholesale would cost
the package lane, so the "do not take" section is as load bearing as the rest.

Dependency facts below were checked against the call sites, not inferred from
the file headers.

## Ranked

| # | What | Cost | Why it is worth it |
|---|---|---|---|
| 1 | `tests/mutate.R` + `assert_green_baseline()` | ~100 lines, adapted | The committed form of the mutation harness this package rebuilt wrong four times |
| 2 | `R/mm_decision_curve.R` | 103 lines, no new dependency | mysterymodel has no net-benefit analysis at all |
| 3 | `R/mm_recalibrate.R` | 459 lines, one new dependency on the clustered path | mysterymodel measures miscalibration and cannot act on it |
| 4 | `R/mm_updating.R` | 125 lines, `stats` only | Closed testing for which update a model actually needs |
| 5 | `R/mm_collinearity.R` | 132 lines, no new dependency | No collinearity diagnostics exist here |
| 6 | `R/mm_iecv.R` | design only, not the code | Internal-external validation by cluster is a stronger claim than bootstrap optimism |
| 7 | `tripod_checklist.R` | pattern | The clinical-reporting twin of the srr verdict ledger |
| 8 | `tests/readme_facts.R` | 144 lines | Re-measures every countable README claim |
| 9 | `tests/fail_open_floor.R` | 51 lines | "A tally is not a result" |

## 1. The mutation harness

`tests/mutate.R` (228 lines) is the highest-value item in the repository and it
is not a feature. It is a harness that independently encodes every failure mode
this package's own mutation work hit, with the incident recorded in the comment
beside each guard:

- **An anchor or file that does not resolve is reported as a SURVIVOR**, never
  an abort and never a pass. That is the `perl \Q` substitution that silently
  did not apply during the W-2/W-3/W-4 campaign, and mutations M10, M11 and M16
  of the round-3 campaign, where the mutation was wrong and the tests were
  blamed first.
- **No output is `NA_integer_`, an explicit third state.** Their note: *"a
  mutation that stops the suite running at all produces no output, so
  `tail(out[nzchar(out)], 1)` is `character(0)`... the harness crashed instead
  of reporting."* The first run of the MW campaign here returned no result line
  for all four mutations and the classifier defaulted the missing result to
  SURVIVED.
- **`assert_green_baseline()` refuses to judge against a red suite**, after a
  real incident: *"reported 57 of 57 killed on 2026-11-21 with two unrelated
  guards failing."* This is the release gate's own rule -- a general package
  error must never count as DETECTED -- enforced in code rather than in prose.
- **A clean `--vanilla` process per mutant**, *"so a mutated definition cannot
  leak into this one."* Compare finding C-1: the autotest bisect here was
  contaminated because the tool left state in its run directory.
- **A `ran` sentinel** separating "a guard noticed" from "the module is
  broken", because the second is not a kill.
- **A timeout**, because a substitution whose result its own loop still matches
  spins forever. One of their harnesses waited 80 minutes.

Porting notes: it is built on `testthat::test_file()` plus `here::here()` and a
`sab()` suite convention this package does not use. Take
`run_suite_against()`'s contract and `assert_green_baseline()`'s rule; drop
`run_sab_suite()` and `run_mutations()`, which serve their suite format. The
natural home is `tests/testthat/helper-mutation.R`, with the mutation list in
one test file so `R CMD check` runs it. Note their own warning that the
mutation LOOPS are deliberately not unified: one of their harnesses must allow
an anchor to match several times because the notebook quotes its own code back.

## 2. `R/mm_decision_curve.R` -- take as-is

Decision curve analysis, net benefit across treatment thresholds. mysterymodel
has none: there is no `net_benefit`, `decision_curve` or `dca` anywhere in
`R/`.

Dependencies: **none new.** `dcurves` appears only in comments, as the
reference the formula was checked against; the code itself uses base R plus
`utils::head`. It relies on base `%||%`, which ships in R >= 4.4, and this
package already declares `R (>= 4.5)`.

It agrees with `dcurves::dca()` to 1.1e-16 on both the model and treat-all
curves at every threshold. Its three documented input defects are in this
package's own house style, and all three were latent because the function it
replaced was defined and never called:

1. a two-level factor outcome returned net benefit 0 at **every** threshold,
   because `obs == 1` on a No/Yes factor is `FALSE` everywhere. A flat zero
   curve reads as "this model has no clinical utility", which is a finding, not
   an error message.
2. one `NA` among the predictions made the whole curve `NA`.
3. a threshold of 1 returned `NaN`, because net benefit divides by `1 - t`.

Those are the same class as findings W-2, W-3 and W-4 here, and worth taking
with the code as negative controls.

Their header also records that publishing a decision curve is gated behind a
declaration of the decision-maker, the action, and the benefit and harm being
traded. That gate is a project policy, not package code, but the distinction it
draws -- computing a thing is not authorising its publication -- is the same
one D-1 settled for the confidence interval.

## 3. `R/mm_recalibrate.R` -- the biggest methodological gap

mysterymodel reports calibration intercept and slope and offers no way to act
on them. This supplies: `mm_recal_intercept()`, `mm_recal_slope()`,
`mm_recal_apply()`, `mm_recal_by()` (stratified, with a `min_n` floor),
`mm_rubin()` (Rubin's rules) and `mm_recal_mi()`.

Dependencies, checked at the call sites: `stats`, plus `sandwich::vcovCL()` at
two lines for cluster-robust standard errors -- so `sandwich` is needed only on
the clustered path and can be `Suggests` with a guard. `mice` appears only in a
comment; `mm_rubin()` is their own implementation. `MM_RECAL` and `MM_HELDOUT`
appear only in comments and one message string, so there is no global to
thread. This is more portable than its line count suggests.

Take their assertion with the code: an intercept correction cannot change the
ranking of any two patients, so the C statistic is unchanged **by arithmetic
rather than by luck**, and their saboteur suite pins exactly that. Their header
also corrects itself on the two-parameter form, and records the measurement
that settled it -- `rms::nomogram` rescales points to `maxscale`, so the
largest movement across all axes under a slope correction measured 0.0000000000
points. That is the kind of claim that should arrive with its measurement
attached.

## 4. `R/mm_updating.R`

`mm_update_test()` and `mm_update_table()`: closed testing across intercept ->
slope -> full revision, returning one row per step and a recommendation of the
least complex adequate update. `stats` only, no globals, 125 lines. The natural
partner to item 3 and to `validation.R`.

## 5. `R/mm_collinearity.R`

`mm_vif_check()` (on `rms::vif`), `mm_redun_check()` (on `Hmisc::redun`) and
`mm_cor_pairs()` (Spearman pairs). mysterymodel has no collinearity or
redundancy diagnostics.

Dependencies: **none new.** `rms` is already an Import and `Hmisc` is already
in Suggests. The only change needed is turning `MM_VIF_MAX`, `MM_REDUN_R2` and
`MM_PAIR_MAX` into arguments with those values as defaults.

## 6. `R/mm_iecv.R` -- take the design, not the code

Bound to `MM_ANALYSES`, `MM_OUTCOME`, `MM_SEED`, `d$app_year` and the shape of
`mm_load()`, so the code does not port. The design does: hold out each cluster
in turn, refuse a fold with fewer than `min_val` rows or `min_events` events in
the rarer class, then pool across folds. `resampling.R` here does bootstrap
optimism, which answers a different question; internal-external cross
validation by cluster is the stronger external claim and is what a clinical
prediction model is usually asked for.

## 7. `tripod_checklist.R` -- the pattern

A TRIPOD+AI reporting checklist where **every study-specific number is read
from an artefact written by the analysis**, and a `need()` helper stops if one
is absent, because *"a checklist that hardcodes its numbers drifts away from
the model it describes and then certifies a model nobody fitted."* Its status
vocabulary refuses to soften: `Met`, `Partial`, `Not reported` -- *"Not
softened, not marked N/A"* -- `Manuscript`, `N/A` with a stated reason.

mysterymodel already has the twin of this discipline in
`test-srr-verdict-ledger.R`, which gates the ledger against the tags rather
than trusting it. TRIPOD+AI is the clinical-reporting analogue, and emitting
one is a reasonable thing for a prediction-model package to offer. Their
version needs `here` and `jsonlite`; a package version would read from the
fitted object and the validation result instead, which removes both.

## 8. `tests/readme_facts.R`

Re-measures every countable claim in the README and **prints rather than
fails**. Directly relevant: the README facts in this package were last updated
by hand. Their finding is the part to read before deciding -- on 2026-11-22
nine README numbers disagreed with disk, and eight separate documentation
contracts were green throughout *"because none of them was ever asked."*

Their argument for a probe over a guard is also worth taking seriously: a
per-number expectation is one more thing to update whenever a guard is added,
*"and the pressure under that friction only ever runs one way: the number gets
lowered until the build is green, which is the defect wearing a ledger entry."*

## 9. `tests/fail_open_floor.R`

One rule, 51 lines: `mm_fail_open_floor(ran, skipped)` fires when a suite
skipped more guards than it executed, and when it executed none at all. The
message is the point: *"Most of this suite did not run and it was about to
report success. Either supply what the skipped guards need, or move the ones
that cannot run here out of this suite. A tally is not a result."*

Stated accurately: **mysterymodel passes this rule today** (2 skipped against
1,549 executed under `R CMD check`), so this is standing insurance rather than
a current catch. It is cheap, and the file it would watch most closely is
`test-calculator-no-interval.R`, whose two source-scanning blocks are the ones
that skip in the check lane -- the guard protecting the D-1 decision.

Their reasoning for a rule instead of a per-suite minimum is the same
anti-ledger argument as item 8, and they have the receipts:
`tests/test_doc_figures.R` ran 2 of 21 checks in CI for its whole history, and
the saboteur suite that was meant to be its negative control ran 6 of 20. Both
were green throughout.

## Do not take

| What | Size | Why not |
|---|---|---|
| `R/mm_redcap_load.R` | 1,777 lines, 39 functions | REDCap-specific loading |
| `R/mm_data_queries.R` | 420 lines | Study-specific queries |
| `R/mm_artifacts.R` | 1,997 lines, 68 functions | Writers for an analysis repository's `output/` tree; a package should not own a filesystem convention |
| `R/mm_year_model.R`, `mm_match_rate_by_year.R` | 295 + | ENT match domain |
| `R/mm_register.R` | 138 lines | Needs `here::here()` and an `output/runs` layout: a new dependency for a project convention |
| `tests/check_tracked_identifiers.R` | 52 lines | Excellent, but it guards a repository that holds applicant data. mysterymodel's fixtures are synthetic, so there is nothing to leak |
| The 101-file test layout | - | Wholesale import would cost the clean package lane |

## Gaps, not imports

Two capabilities are real gaps that should not be resolved by copying, because
they change statistical behaviour and are owner decisions:

**Missing data.** `R/mm_imputation.R` plus `R/mm_mice_diag.R` (337 + 262
lines) would end this package's complete-case-only limitation -- the one
`mm_predict()` currently refuses with "Impute first, or pass `on_missing =
"na"`". It adds `mice`, and multiple imputation changes what every reported
number means, so it needs a decision and a validation plan, not a copy.

**Penalisation.** `R/mm_penalization.R` and `R/mm_penalty.R` are the missing
*answer* to the Riley overfitting warnings this package already emits: it tells
a user their sample is too small and offers no remedy. But `mm_fit_penalized()`
takes a `mids` object, so it rides on the imputation decision above.

Also noted, nothing to take: `R/mm_riley.R` (350 lines) and `R/mm_performance.R`
(329 lines) overlap `sample_size.R` and `validation.R` here. `mm_performance.R`
pulls `pmcalibration` and `psfmi`, which is two dependencies for capability
this package already has.

## Suggested order

1. Item 2, `mm_decision_curve.R`: self-contained, no new dependency, closes a
   real clinical gap. Take its three negative-control tests with it.
2. Item 1, the harness: converts today's throwaway campaign into a standing
   gate. Do this before items 3 and 4, so their guards arrive with mutation
   evidence rather than assertions.
3. Item 5, `mm_collinearity.R`: no new dependency, three globals to arguments.
4. Items 3 and 4 together, recalibration and updating, with `sandwich` in
   Suggests behind a guard. These change what the package claims it can do, so
   they want the harness from item 1 already in place.
5. Items 7, 8 and 9 as reporting and suite hygiene, in any order.
6. Items 6, imputation and penalisation only after an owner decision.
