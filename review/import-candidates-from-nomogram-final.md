# Proposed imports from nomogram-final

Status: **STAGED / UNVERIFIED**. This is a review branch, not a release.
Source: `mufflyt/nomogram-final`, main, inspected 2026-11-22.
Destination: `mufflyt/mysterymodel`, branch
`feature/nomogram-final-ports-20261122`.

## What was staged

| Request | Destination | Porting status |
|---|---|---|
| Mutation harness and green baseline | `tests/mutate.R` | Adapted for testthat and clean Rscript process; not yet run |
| Net benefit / DCA | `R/mm_decision_curve.R` | Ported with explicit factor event-level guard |
| Recalibration | `R/mm_recalibrate.R` | Portable core functions staged; no ENT pipeline |
| Closed model-updating test | `R/mm_updating.R` | Source algorithm staged, not externally verified |
| Collinearity | `R/mm_collinearity.R` | Globals replaced by arguments |
| Internal-external CV | `R/mm_iecv.R` | Fresh native implementation, not an ENT-code copy |
| TRIPOD reporting | `R/mm_tripod_checklist.R` | Generic evidence-backed engine, not a full checklist |
| README fact probe | `tests/readme_facts.R` | Non-gating probe; must be invoked explicitly |
| Fail-open floor | `tests/fail_open_floor.R` | Standalone rule; CI integration still required |

Tests staged under `tests/testthat/test-*-port.R`.

## Important differences from the original

- Decision-curve factor outcomes require an explicit `positive` level.
  This prevents silent inversion of the event definition.
- The recalibration file includes `mm_logit` (internal),
  `mm_recal_intercept`, `mm_recal_slope`,
  `mm_recal_apply`, `mm_recal_by`, and `mm_rubin`.
  It excludes ENT-specific `mm_recal_axis` and the multiple-imputation
  driver `mm_recal_mi`.
- `mm_recal_apply` refuses a zero or negative slope, because it
  would destroy the promised ranking invariant.
- Collinearity thresholds are arguments rather than global variables.
- `mm_iecv` refuses underpowered folds instead of silently removing them.
  If a study declares `cluster_id`, subjects overlapping training and
  holdout are refused.
- TRIPOD evidence currently reads CSV artifacts and requires an explicit
  status per reporting item. It does **not** claim a full TRIPOD+AI item
  catalog has already been mapped or verified.
- The mutation harness refuses a red baseline, uses a fresh process,
  requires a sentinel showing tests ran, requires the intended test to
  fail, marks missing anchors as survivors, and restores source files.
  A crashed test process is INVALID, not DETECTED.

## Verification still required before merging

1. Run `devtools::document()` in a local R 4.5+ session to regenerate
   the namespace and all Rd files. The staged NAMESPACE was wired
   manually because this environment cannot execute R.
2. Run `devtools::test()` and `devtools::check()` and preserve the
   exact check output and tested commit.
3. Check with `pkgload::load_all()` and from a clean installed-package
   session that all exported functions are registered.
4. Run existing prediction/validation tests to prove unchanged numeric
   predictions, confidence intervals, resampling, and calculator UI.
5. Independently compare decision-curve calculations against
   `dcurves::dca()` where available; check factor outcomes, missingness,
   and threshold endpoints.
6. Review recalibration uncertainty, especially whether cluster-robust
   covariance can ever fall back silently when `sandwich` is absent.
   Require explicit documentation and an error for unsupported inference.
7. Test `mm_update_test()` against nested-model reference calculations.
   Its recommendation is a proposal, not independent validation of the
   updated model. Explicitly validate any model revision formula.
8. Test all IECV folds, missingness, patient overlap, and pooled estimates
   against a manually constructed reference. This is a new implementation,
   not a verified verbatim transfer.
9. Add a full TRIPOD+AI item catalog, evidence mapping, and documentation;
   no item may be marked Met without verified written evidence.
10. Prove the mutation harness detects intended mutations and refuses
    unrelated errors, empty output, red baselines, missing anchors, and
    timeouts. Add automated self-tests.
11. Wire the fail-open floor into CI using genuine testthat execution and
    skip counts; merely committing the helper is not a protection.
12. Keep the README fact probe informational, and explicitly review its
    reported counts instead of claiming a successful probe proves prose
    correctness.
13. Obtain an independent code review. No merge until release blockers
    are resolved.

## Explicitly excluded

- `mm_redcap_load.R`, `mm_data_queries.R`: REDCap-specific.
- `mm_year_model.R`, `mm_match_rate_by_year.R`: ENT-specific.
- `mm_artifacts.R`, `mm_register.R`: analysis-run filesystem
  conventions, not a portable package API.
- The source repository's full test tree.

## Separate PI decisions

- Multiple imputation with `mice`: **NOT IMPORTED**.
  Its methods and uncertainty accounting require explicit approval.
- Penalized fitting: **NOT IMPORTED**. The source's fitting path depends
  on the imputation decision and would alter statistical behavior.

## Release rule

Do **not** treat this branch as complete merely because the source files
are present. It has not been compiled, tested, checked, or independently
reviewed on this branch. Do not merge or use these functions for clinical
decisions until those gates close.
