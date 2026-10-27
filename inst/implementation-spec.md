# mysterymodel: Implementation Specification

**Status:** Proposed architecture and implementation contract  
**Date:** 2026-10-26  
**Working package name:** `mysterymodel` (retain `clinpredict` as an alternate until name clearance)  
**Public function prefix:** `cp_` (subject to API review)  
**Core objective:** Reproducible clinical prediction modeling from raw data through validated estimates, interpretable models, patient-level prediction, and Quarto manuscripts.

## 1. Mission, boundaries, and non-negotiables

Build a thin, well-tested orchestration package around established R statistical packages. Do not reimplement fitting, imputation, resampling, or plotting methods where a maintained package already provides a defensible implementation. Use `rms` for reference clinical regression and for canonical nomograms. Integrate easystats for diagnostics and interpretation, `tidymodels` components where they provide value, and `duckplyr`/Arrow for large-data preprocessing. Preserve native model objects and their methods.

**Must support:** Binary outcome first; continuous and survival outcomes in later releases. Small clinical samples with sparse events and large observational datasets. Clean, label, summarize, prespecify, fit, internally validate, calibrate, explain, predict, export, and report. Provide an opt-in scalable alternative for fitting, not an implicit substitution for `rms`. All reports must distinguish development, validation, and external evaluation.

**Must not:** Automatically screen predictors by univariate p-values; turn continuous variables into arbitrary categories; confuse odds ratios with risks; present apparent performance as validated; fit on future observations during temporal validation; use imputed or processed holdout information in training; label exploratory interactions as confirmed; claim out-of-memory support for `rms`; silently downsample; silently delete observations; report bootstrap validation from a pipeline whose selection/tuning occurred outside its resamples; export PHI into logs or reports.

## 2. Statistical priorities

1. Preserve a written analysis plan and candidate parameter budget before fitting. Use `pmsampsize` or equivalent development-sample calculations when applicable; report sample size, outcome events, outcome prevalence, number of candidate predictor parameters (including splines/interactions), and anticipated shrinkage.
2. Define outcomes, positive class, measurement timing, prediction horizon, eligible population, intended clinical use, candidate predictors, transformations, clinically motivated interactions, and resampling plan before model development.
3. Default binary model: `rms::lrm()` with `x=TRUE`, `y=TRUE`, model terms and `datadist` preserved. Inference versus prediction goals must be declared, because variable selection and interval interpretation differ.
4. Support nonlinear continuous effects with `rms::rcs()` and sensible knot policies. Plot and test aggregate nonlinear terms, not individual spline coefficients. Avoid dichotomizing continuous predictors without justification.
5. Prefer prespecified clinical predictors. Provide explicitly labeled penalized, stability, and exploratory selection routes. Count all degrees of freedom considered. If using LASSO-selected variables followed by ordinary regression, flag selection-induced optimism and inferential invalidity; do not represent naïve confidence intervals as selection-adjusted.
6. Missingness must be characterized before fitting. Support complete-case sensitivity analyses and multiple imputation (`mice`/`Hmisc`/`rms`) with documented assumptions. Imputation models may include the development outcome where statistically appropriate, but never leak validation/test outcomes into the development pipeline. Define how patient-level predictions will handle missing predictors in deployment.
7. Respect strong hierarchy for interactions: an interaction is only usable with its constituent main effects. Primary prespecified interaction tests should evaluate blocks jointly, e.g. `rms::anova()`. Exploratory interaction discovery may use `glinternet`, restricted candidate sets, and bootstrap selection stability, but all selection/tuning must be nested within development resampling. Report additional degrees of freedom and clinical effect scales, not just p-values.
8. Internal validation must reproduce the **entire data-dependent modeling strategy** in each training resample, including learned preprocessing, imputation, feature selection, tuning, and interaction screening, if those steps are part of the strategy being validated. Distinguish fixed-model validation from modeling-strategy validation, and distinguish an `rms::validate()` reference workflow from custom end-to-end resampling. Guard against invalid application of optimism correction when the pipeline includes multiple imputation.
9. Evaluation for binary outcomes: AUC/C statistic with uncertainty, Brier score with prevalence benchmark, calibration intercept, calibration slope, calibration-in-the-large as appropriate, flexible calibration curve, calibration error summaries with explicit definitions, event counts, and discrimination/calibration by relevant subgroups when supported. Label confidence interval method and bootstrap unit. Consider decision-curve analysis (`dcurves`) with prespecified clinically relevant thresholds; do not confuse clinical utility with AUC.
10. Additional designs: grouped/patient-clustered bootstrap, temporal forward chaining, future-year lockbox evaluation, rare-event handling, and survival censoring-aware assessment. The future-year holdout must never be used for choosing predictors, splines, hyperparameters, or interaction terms; if used iteratively, label it model development rather than pristine external validation.
11. Univariate results are descriptive/unadjusted associations. Label them as such; never call them independent predictors. Produce effect sizes and confidence intervals alongside optional p-values, multiplicity notes where appropriate, and denominator information.
12. Reporting aligns to TRIPOD+AI; produce a machine-readable checklist, documenting missing items without manufacturing content. PROBAST/PROBAST+AI risk-of-bias assessment may be an optional review aid and must not automatically certify low risk of bias.

## 3. Ecosystem ownership

| Layer | Primary packages | Rule |
|---|---|---|
| Manipulation | `dplyr`, `tidyr`, `duckplyr`, `arrow`, `duckdb` | Prefer tidyverse API; duckplyr when supported; log fallbacks and materialization |
| Quality control | `pointblank`, `checkmate`, `janitor` | Retain reject/quarantine records and explicit cleaning audit |
| EDA | `skimr`, `naniar`, `visdat`, `GGally` | Show denominators, missingness and meaningful scales |
| Statistical diagnostics | `performance`, `correlation`, `parameters`, `effectsize`, `insight`, `datawizard`, `modelbased`, `see`, `report` | Use selected easystats packages as optional dependencies; preserve native object outputs |
| Descriptive and manuscript tables | `gtsummary`, `gt`, `broom`, `ggplot2` | Means with SD; medians with p25/p75; thousands separators; percentages with one decimal |
| Imputation | `mice`, `Hmisc`, `rms` | Keep imputation inside validation where required |
| Models | `rms` primary; `glmnet`, `brglm2`, `parsnip` alternatives | Explicit engine selection; do not silently change estimators |
| Interaction screening | `rms`, `glinternet` | Prespecified tests primary; exploratory screens clearly labeled |
| Resampling and metrics | `rms`, `rsample`, `yardstick`, `pROC`, `probably` | Exact resampling splits and seeds saved |
| Clinical utility | `dcurves` | Interpret threshold ranges clinically |
| Graphics/export | `rms`, `ggplot2`, `patchwork`, `ragg`, `svglite` | Nomograms tied to canonical model |
| Reports/reproducibility | `quarto`, `targets`, `renv`, `digest`, `testthat`, `withr` | Immutable timestamped artifact bundles; manifest checksums |

Avoid importing an entire meta-package merely for convenience. Inspect supported class/method compatibility before applying any easystats helper to an `rms` object. Functions with unsupported model classes should return a useful diagnostic or use a separately tested adapter, not silently convert estimates.

## 4. Public API and typed artifacts

Use `cp_` functions with stable inputs, explicit required arguments and structured returns:

- `cp_project()` creates validated analysis configuration.
- `cp_import()` reads data frames, CSV, RDS, Parquet, Arrow datasets and known lazy sources; reports backend and materialization policies.
- `cp_dictionary()` defines variable types, labels, measurement units, ranges, permissible factor levels, timing, protected metadata, and missing-value codes.
- `cp_clean()` produces cleaned cohort plus machine-readable inclusion/exclusion and transformation ledger.
- `cp_profile()` reports counts, duplicates, missingness, variable distributions, and anomalies.
- `cp_eda()` generates Table 1-ready summaries and EDA figure objects.
- `cp_univariate()` creates descriptive and unadjusted estimates with explicit missing denominators.
- `cp_collinearity()` computes pairwise correlations, VIF/GVIF when valid, rank deficiencies and condition indices on the actual model matrix, accounting for categorical factors and splines.
- `cp_select()` implements prespecified and penalized procedures; emits selected feature terms and stability/selection audit.
- `cp_interactions()` documents hypotheses, fits hierarchical terms, tests interaction blocks, creates absolute-risk plots, and evaluates predictive contribution.
- `cp_model()` returns an engine-native fitted object plus preprocessing recipe, data dictionary, model specification, prediction schema, and reference checksum.
- `cp_validate()` implements declared optimism-corrected bootstrap, resampling, cluster/temporal strategies, or lockbox evaluation and returns metrics with uncertainty and complete split manifest.
- `cp_calibrate()` returns calibration estimates and plots, with clearly defined apparent/optimism-corrected/held-out basis.
- `cp_predict()` generates response-scale predictions from exactly the deployed model, with factor-level, missingness, units, and range checks.
- `cp_explain()` reports predictor effects, marginal/adjusted predictions, and risk contributions, labeling any model-specific limitations.
- `cp_nomogram()` uses canonical `rms::nomogram()` from the fitted `rms` model and identical `datadist` and prediction transformation; exports accessible plots.
- `cp_report()` creates Quarto-ready summaries, tables, figures, methods text, limitations, TRIPOD+AI checklist, and a machine-readable reporting bundle.
- `cp_export()` saves an immutable timestamped bundle, manifests all files with hashes, validates paths and model/prediction equivalence.

Do not name intermediate R variables `results`, `df`, `data`, `out`, `output`, or `final`. Qualify non-base package function calls explicitly (e.g. `dplyr::filter()`); avoid `dbplyr` unless needed for an explicitly supported database pathway. Roxygen and code lines should be ≤80 characters. Use `base::message()` for rich logging of inputs, data transformations, row counts, elapsed times, outputs, and exact saved paths. Never log patient-identifying values.

## 5. Config-driven orchestration

A project configuration must contain: study slug; version; outcome/event coding; data dictionary; event definition; eligibility criteria; observation and index times; candidate predictors and parameter budget; missing-data strategy; declared model family; prespecified spline and interaction terms; variable-selection policy; resampling strategy and unit; random seeds; metric definitions; export formats; privacy safeguards; and reporting metadata.

`cp_project()` validates mutually incompatible settings before running. Example errors: temporal validation without a time field; clustered bootstrap without ID; nomogram requested for a non-`rms` model; insufficient variation in an outcome; unrecognized factor levels; candidate predictor measured after outcome time; attempts to impute using the locked holdout.

## 6. Small vs. large datasets

**Small cohort mode:** `rms`-centered, imputation-aware, event/parameter-limited, conservatively specified. Treat the Elena UDS analysis as a regression test once its actual source, datasets, variable dictionary, and reference outputs are available; don't presume the attached narrative is executable ground truth. A sample with ~57 events requires particular restraint in degrees of freedom and exploratory interactions.

**Large-data mode:** `duckplyr` and Arrow for lazy transformations, quality checks, aggregations and EDA; track query plans, rows/materialization, peak-memory safety estimates and fallbacks. A scalable estimator must be explicitly named, tested, and accompanied by a documented prediction interface. Never suggest that lazy data cleaning makes `rms::lrm()` out-of-memory. If there is no supported scalable fitting path, fail closed with alternatives (data reduction declared by analyst or alternate estimator). Large datasets must not cause accidental implicit collection into memory.

## 7. Nomogram contract

The canonical nomogram must be computed with `rms::nomogram()` on the exact fitted `rms` model with correct `datadist`, coefficient vector, factor coding, offsets, knot specification, and outcome inverse-link. Use clinically meaningful units and absolute risks, not just linear-predictor labels. Default landscape width 13 inches, height 9 inches; provide full-page, landscape, and multipage fallback. Export vector PDF and SVG, plus 300–600 DPI PNG via `ragg`. Support long-label wrapping, minimum text size, adequate axis spacing, factor-level readability, and special handling of spline/interaction complexity. Never change the fitted model to fit a page. If too complex, flag as visually overloaded and recommend a calculator as the main interface with an unaltered technical nomogram supplement.

Render and inspect an automated fixture set (few predictors, many predictors, nonlinear effects, categorical effects, interaction, long labels). The generator must reject clipped labels and missing labels when detected and require visual review on changed plotting logic. Numerical points-to-risk regression tests must agree with `cp_predict()` at predefined clinically relevant profiles within stated floating-point tolerance. A nominally generated PDF does not satisfy the acceptance gate if illegible at 100% viewing size.

## 8. Prediction and model transport

Every prediction artifact must include outcome definition and horizon, positive event label, predictor schema, allowed factor levels, preprocessing and imputation policy, model version, provenance hash, and explicit action on out-of-range/new-level/missing inputs. Export predicted probability and interval/uncertainty only when the method supports a valid interpretation. Predictions must be independently reconciled with native `predict()` on reference patients and across serialization/deserialization. Do not treat a nomogram as a substitute for testing deployed calculator predictions. Clearly distinguish training, internal validation, future-period test and external transportability.

## 9. Quarto and writing contract

Quarto loads previously generated, verified artifacts; it must not rerun fitting accidentally on document render. Templates: clinical prediction report, model diagnostics, and validation appendix. All displayed estimates, figures, manuscript sentences, and model parameters must derive from the same manifest-pinned files.

Produce: cohort flow diagram and numbers; missingness report; descriptive Table 1; univariate table explicitly labeled; prespecified/selected candidate record; spline and interaction diagnostics; model coefficient table; model formula and parameters; discrimination, Brier, calibration intercept and slope with uncertainty; calibration plot; optional decision curve; nomogram; prediction examples using synthetic or approved de-identified data; limitations and TRIPOD+AI checklist.

Dynamic text should compute observed years, N/events, study direction (when a defined comparison exists), formatted p-value where statistically appropriate, AUC/CI, calibration, and optimism-correction status. Format counts with thousands separators, percentages to one decimal, means (SD), and medians (p25, p75). Never manufacture a year, trend, direction or p-value when the corresponding variables or inferential comparison are unavailable. Manuscript text must not claim causal effects or independent predictors from unadjusted statistics.

## 10. Provenance, Ponytail review and failures

- Independent implementers and read-only statistical reviewers. Review methods, leakage, interval semantics, calibration, nomogram, visual quality, performance, and privacy separately.
- Fail closed on outcome/timing leakage, cross-year contamination, invalid positive-level coding, missing resample membership, unexpected outcome transformations, coefficient/prediction mismatch, unsupported engine assumptions, or incomplete manifest.
- Every artifact has a SHA-256 fingerprint and upstream identifiers: input fingerprint, code commit, project specification hash, package lockfile, random seed, split IDs, date/time, model object fingerprint, canonical formula, and export options.
- Immutable timestamped paths, e.g. `artifacts/20261026_192100/`, never overwritten silently.
- `base::message()` logs input source type (not PHI), dimensions, cleaning counts, transformation names, resample progress, warnings, metric generation, saved artifact hashes and exact paths.
- Restrict stored patient-level predictions and originals; no PHI in build logs, snapshots, vignettes or CI fixtures. Synthetic fixtures for public repo.
- A CI gate cannot be waived by text edits alone; tests require reproducible evidence and independent reviewers must acknowledge changes to statistical estimands.

## 11. Repository modules

```text
mysterymodel/
  DESCRIPTION
  NAMESPACE
  R/
    project.R
    dictionary.R
    import.R
    cleaning.R
    profiling.R
    eda.R
    univariate.R
    collinearity.R
    selection.R
    interactions.R
    modeling_rms.R
    modeling_alternatives.R
    imputation.R
    resampling.R
    validation.R
    calibration.R
    prediction.R
    explanation.R
    nomogram.R
    reporting.R
    provenance.R
    logging.R
    utils_checks.R
  inst/
    quarto/
      clinical_prediction.qmd
      model_diagnostics.qmd
      validation_appendix.qmd
    schemas/
      project.schema.json
      prediction.schema.json
      manifest.schema.json
  tests/testthat/
    test-cleaning.R
    test-imputation.R
    test-model-reference.R
    test-interactions.R
    test-temporal-leakage.R
    test-validation.R
    test-calibration.R
    test-predictions.R
    test-nomogram.R
    test-large-data.R
    test-provenance.R
    fixtures/
  vignettes/
  data-raw/
```

Sample analysis artifact layout:

```text
artifacts/20261026_192100/
  model/model.rds
  model/datadist.rds
  model/prediction_schema.json
  tables/table1.rds
  tables/univariate.rds
  tables/collinearity.rds
  tables/model_coefficients.rds
  figures/missingness.svg
  figures/predictor_effects.svg
  figures/interactions.svg
  figures/calibration.svg
  figures/nomogram.pdf
  figures/nomogram.svg
  figures/nomogram.png
  validation/metrics.rds
  validation/resample_assignments.rds
  reports/clinical_prediction.qmd
  reports/tripod_ai_checklist.json
  manifest.json
```

## 12. Release roadmap and acceptance gates

### v0.1 — cohort contract, cleaning, profile and EDA
Implement dictionary, import, cleaning ledger, quality checks, descriptive and univariate tables, missingness summaries and collinearity. Fixtures include row exclusions and known missingness rates. **PASS:** reproducible cohort counts, exact descriptive reference numbers, no silent row deletion, small/large backends semantically equivalent for supported operations, no accidental materialization.

### v0.2 — `rms` modeling, nonlinearity, interaction and selection
Implement `lrm`, formula helpers, `datadist`, spline and hierarchical interaction logic, alternative model interfaces and audit trails. **PASS:** fitted coefficients and predicted probabilities match direct reference `rms` fits within declared numeric tolerances; all factor/interaction hierarchies correct; parameter budget and selection risks documented; negative leakage tests fail as expected.

### v0.3 — complete development strategy, internal validation and nomograms
Implement nested training-only preprocessing, imputation, selection/tuning, optimism bootstrap, temporal/grouped validation, calibration, Brier/AUC, prediction schema, native nomogram and export. **PASS:** synthetic fixtures verify no holdout leakage, bootstrap re-executes declared strategy, prediction equivalence before/after serialization, reference metric agreement, readable and unclipped nomogram PDF/SVG/PNG with documented review.

### v0.4 — Quarto, scalable modes and provenance
Implement artifact manifest, immutable timestamped bundles, Quarto reports, large-data lazy processing checks, model engine capability matrix, complete CI gates and independent review. **PASS:** one command produces exact manuscript tables, figures, sentences and model provenance from one manifest; report render never refits; all outputs checksum; clean-session reproduction and PHI-safe logs.

## 13. Mandatory automated fixture suite

1. Complete binary cohort with known logistic coefficients and near-exact prediction reference.
2. Small, sparse-event binary cohort; warns on overly ambitious predictor parameter count.
3. Numeric predictor with nonlinear risk; grouped spline-term inference.
4. Categorical levels with rare/reference levels; invalid levels fail at prediction.
5. Known interaction and null interaction; full interaction hierarchy and risk-scale plots.
6. Perfect collinearity, high correlation, and categorical GVIF edge cases.
7. MCAR/MAR-like missingness and nested imputation; no cross-resample contamination.
8. Outcome predictor measured after index date; detected as leakage.
9. Repeated-patient clustering; whole-patient resampling.
10. Multiple calendar years with temporal drift; strict forward-chaining and future-only tests.
11. Separated logistic data; warning/alternative estimation explicit.
12. Many-predictor nomogram with long labels; visual overflow gate and export verification.
13. Millions of lazy rows or simulated on-disk fixture; prove bounded materialization.
14. Model save/reload plus patient prediction parity; direct numeric audit.
15. Tampered manifest; integrity gate fails before Quarto render.

## 14. Implementation workflow and definition of done

Start with a capability matrix and package-compatibility spike, not a wholesale implementation. Confirm `rms` class support for each easystats diagnostic; list supported/non-supported methods. Then write the fixture datasets, authoritative reference calculations, and adversarial tests before production modules. Develop one stage at a time, request independent statistical and technical review, and merge only after gates pass. Do not attempt parallel simultaneous development of incompatible model interfaces.

A version is done only when its intended workflow can be run in a fresh R environment, all tests pass, model estimates and prediction artifacts match the frozen reference fixtures (or intentional, separately justified methodological changes are recorded), no leakage or privacy gate fails, and generated nomograms and Quarto documents have been inspected.

## 15. Practical starting milestone

For first operational success, make a **small-data binary `rms` end-to-end vertical slice** with synthetic UDS-like data: `cp_project()` → `cp_clean()` → `cp_eda()` → `cp_model()` → `cp_validate()` → `cp_calibrate()` → `cp_nomogram()` → `cp_report()` → `cp_export()`. Include nonlinearity and one prespecified interaction fixture. Then compare with the actual `/uti_uds/Elena.Rmd` and its verified data/results **only when those files are accessible**; do not claim equivalence without reading them. Add exploratory glinternet and large-data fitting only after the statistical baseline is stable.

## 16. Outstanding design decisions to settle before implementation

- Final package/name availability and `cp_` prefix choice.
- Minimum supported R version and operating systems.
- Which outcome families to support in v0.1 (recommend binary first).
- How to package portable imputers for new individual predictions.
- Whether a report can contain patient-level examples (recommend synthetic examples by default).
- Accepted calibrated-risk interval method, if any, and bootstrap CI calculation.
- Which scalable model-fitting backend(s) to support (no unapproved default).
- Whether reference analysis is intended to reproduce legacy methodology exactly or produce a separately labeled methodologically corrected successor.
