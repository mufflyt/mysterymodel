# Changelog

## mysterymodel 0.0.0.9000

First development version; nothing is released yet. This records the
history by theme rather than by version. Each entry names the pull
request that made the change and, where a question had to be settled
rather than merely implemented, the record in `inst/decisions.md` that
settled it.

### The pipeline

- `mm_full_process(refit = )` and `mm_validate(refit = )` take a
  `function(project, draw)` returning an `mm_model`, re-executed inside
  every resample, so a strategy that selects, tunes or imputes can have
  the optimism of those choices in its correction instead of excluded
  from it. It is called once on the development rows first and must give
  the same equation as the model being corrected; a `refit` that fits
  something else is refused there, after one fit rather than after `B`
  of them, because an optimism measured on a different strategy is wrong
  in no visible way.

- `covers` and the new `held_fixed` are **computed from the call**, and
  the note is derived from both. They used to be a literal vector and a
  literal sentence saying “imputation, selection and tuning are not in
  this pipeline yet”, written when that was true and still printed after
  [`mm_splines()`](https://mufflyt.github.io/mysterymodel/reference/mm_splines.md)
  and
  [`mm_interactions()`](https://mufflyt.github.io/mysterymodel/reference/mm_interactions.md)
  shipped — so a caller who screened with one of those, picked a term
  and then validated was told the one thing they most needed to doubt,
  and `test-full-process.R` asserted the sentence. `held_fixed` now
  names each data-dependent choice the resample inherited instead of
  re-making (“which predictors are splined”, “which interactions are in
  the model”) and says that holding it fixed is correct only if it was
  prespecified.

- [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
  refuses to overwrite an exported sheet, and takes `id` to distinguish
  two of them. Both fits of a project write `<slug>_nomogram.pdf`, so
  the second silently replaced the published sheet of the first with
  nothing on disk recording which was which. A figure is as destroyable
  as a table.

- [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md),
  [`mm_clean()`](https://mufflyt.github.io/mysterymodel/reference/mm_clean.md),
  [`mm_eda()`](https://mufflyt.github.io/mysterymodel/reference/mm_eda.md),
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md),
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md),
  [`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md),
  [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md),
  [`mm_interactions()`](https://mufflyt.github.io/mysterymodel/reference/mm_interactions.md),
  [`mm_splines()`](https://mufflyt.github.io/mysterymodel/reference/mm_splines.md),
  [`mm_calculator()`](https://mufflyt.github.io/mysterymodel/reference/mm_calculator.md)
  and
  [`mm_synthetic_cohort()`](https://mufflyt.github.io/mysterymodel/reference/mm_synthetic_cohort.md)
  are the whole public surface. Everything else is internal
  ([\#1](https://github.com/mufflyt/mysterymodel/issues/1),
  [\#2](https://github.com/mufflyt/mysterymodel/issues/2),
  [\#3](https://github.com/mufflyt/mysterymodel/issues/3)).

- The public prefix is `mm_`
  ([\#4](https://github.com/mufflyt/mysterymodel/issues/4), DEC-002).

- [`mm_clean()`](https://mufflyt.github.io/mysterymodel/reference/mm_clean.md)
  returns a ledger that reconciles. Rows in must equal rows out plus
  every exclusion, and a mismatch is an error rather than a note,
  because a cohort count that cannot be reconciled against the raw
  export is the commonest reason a published flow diagram does not add
  up ([\#2](https://github.com/mufflyt/mysterymodel/issues/2)).

- [`mm_eda()`](https://mufflyt.github.io/mysterymodel/reference/mm_eda.md)
  carries the denominator each percentage is taken over and the missing
  count beside it, so a percentage computed over the complete rows
  cannot read as a fact about the cohort
  ([\#2](https://github.com/mufflyt/mysterymodel/issues/2)).

- [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
  reads the drawn nomogram back the way a clinician reads it and refuses
  to return one that disagrees with
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
  ([\#3](https://github.com/mufflyt/mysterymodel/issues/3)).

- Requires R 4.5
  ([\#15](https://github.com/mufflyt/mysterymodel/issues/15)). An exact
  patch-level dependency is not expressible: `R CMD check --as-cran`
  rejects `R (>= 4.5.2)`.

### Honest performance reporting

- [`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
  returns one row per basis, because apparent, bootstrap-corrected and
  held-out numbers are not interchangeable and presenting one as another
  is the commonest way a published model flatters itself
  ([\#3](https://github.com/mufflyt/mysterymodel/issues/3)).
- The fixed-model bootstrap is labelled as what
  [`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html) does:
  it refits one formula and does not re-derive anything the formula was
  chosen by.
  [`mm_full_process()`](https://mufflyt.github.io/mysterymodel/reference/mm_full_process.md)
  refits the whole strategy inside every resample and names what it
  re-executes ([\#3](https://github.com/mufflyt/mysterymodel/issues/3)).
- Clustered resampling draws whole patients when the project declares a
  cluster, including inside
  [`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html), which
  takes a `cluster` through `predab.resample()`. Resampling rows under a
  clustered design narrows every interval it touches
  ([\#9](https://github.com/mufflyt/mysterymodel/issues/9)).
- Resamples that `rms` could not fit are read off its `n` column and
  disclosed. Its own report of the shortfall is behind `pr`, which
  defaults off, so a corrected index could be an average over a
  self-selected subset with nothing on the object to say so
  ([\#9](https://github.com/mufflyt/mysterymodel/issues/9)).
- Apparent calibration is withheld rather than printed as 0 and 1.
  Scoring an unpenalized fit on its own rows forces both, so they
  describe the estimator and not the model. The identity is detected
  rather than assumed, so a penalized fit keeps its estimate
  ([\#10](https://github.com/mufflyt/mysterymodel/issues/10)).
- One scaled-Brier reference down the whole column, the development
  cohort’s own, because a column of scores against different references
  is a comparison a reader will make and should not
  ([\#11](https://github.com/mufflyt/mysterymodel/issues/11)).
- The c-statistic comes from the ROC and its bounds from the interval,
  which are two computations. Reading the estimate out of the middle of
  `ci.auc()` discarded a calculable c-statistic whenever DeLong could
  not be computed
  ([\#11](https://github.com/mufflyt/mysterymodel/issues/11)).
- Every interval names its method and the event and non-event counts it
  rests on, in a new `non_events` column. An interval that cannot be
  computed is `NA` with the reason; one of zero width, which is what
  DeLong returns on complete separation or complete ties, says so rather
  than reading as precision; a limit truncated at the edge of the
  parameter space is named a bound. A corrected c-statistic carries no
  interval and says why: that needs a nested bootstrap, which is not
  implemented
  ([\#19](https://github.com/mufflyt/mysterymodel/issues/19), DEC-006).

### Acting on what validation measures

Ported from the `nomogram-final` analysis repository this package was
extracted from, where each had been written against a real failure.
Three capabilities the package measured but could not act on, or did not
have:

- [`mm_recal_intercept()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_intercept.md),
  [`mm_recal_slope()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_slope.md),
  [`mm_recal_apply()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_apply.md),
  [`mm_recal_by()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_by.md),
  [`mm_rubin()`](https://mufflyt.github.io/mysterymodel/reference/mm_rubin.md)
  and
  [`mm_recal_mi()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_mi.md)
  recalibrate a frozen model.
  [`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
  reported a calibration intercept and slope and offered no way to
  correct them, which matters because a reader takes an absolute
  probability off a nomogram’s bottom axis, so a bias on the log-odds
  scale is the error that reaches them and discrimination says nothing
  about it. A correction is monotone, so it cannot reorder any two
  patients and cannot repair discrimination: that is asserted, not
  assumed. `b` is tested against 1 rather than 0, because a slope
  correction of 1 is no correction. Standard errors are cluster-robust
  when a cluster is given and `sandwich` is installed, and the returned
  `cluster_robust` flag says which was used rather than leaving a caller
  to assume. Pooling across imputations goes through Rubin’s rules,
  because averaging the estimates alone reports the within-imputation
  error as the whole uncertainty and hides the between-imputation
  variance, making an interval too narrow precisely because the missing
  data were handled properly.

- [`mm_decision_curve()`](https://mufflyt.github.io/mysterymodel/reference/mm_decision_curve.md)
  computes net benefit across treatment thresholds, which the package
  had no form of. The arithmetic agrees with
  [`dcurves::dca()`](http://www.danieldsjoberg.com/dcurves/reference/dca.md)
  to 1e-12 at every threshold, including ties exactly on the threshold;
  `dcurves` is a test-time reference and not a dependency. Computing a
  decision curve is not the same as being entitled to publish one: net
  benefit is an explicit trade of a benefit against a harm and means
  nothing until the decision-maker, the action and the two outcomes
  being traded are named.

- [`mm_vif_check()`](https://mufflyt.github.io/mysterymodel/reference/mm_vif_check.md),
  [`mm_redun_check()`](https://mufflyt.github.io/mysterymodel/reference/mm_redun_check.md),
  [`mm_cor_pairs()`](https://mufflyt.github.io/mysterymodel/reference/mm_cor_pairs.md)
  and
  [`mm_collinearity_report()`](https://mufflyt.github.io/mysterymodel/reference/mm_collinearity_report.md)
  are collinearity diagnostics, which the package had none of. Three
  questions, because each misses what the others catch: variance
  inflation is per parameter and blind to a variable predictable from a
  combination of others while correlating strongly with none; redundancy
  asks exactly that; the Spearman pair matrix names the pair a human can
  act on.
  [`mm_collinearity_report()`](https://mufflyt.github.io/mysterymodel/reference/mm_collinearity_report.md)
  requires the cohort and checks it against the model’s development
  fingerprint, because
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  does not retain the rows it was fitted on and diagnostics on a
  different frame of the same shape would read as though they described
  the fit.

[`mm_vif_check()`](https://mufflyt.github.io/mysterymodel/reference/mm_vif_check.md)
gates on the PER-VARIABLE generalized variance inflation factor (Fox and
Monette), computed from the correlation matrix of the coefficient
estimates, and reports the per-parameter
[`rms::vif()`](https://rdrr.io/pkg/rms/man/vif.html) figures beside it,
labelled. The distinction is not cosmetic: the bases of one restricted
cubic spline are collinear with each other by construction, so on an
ordinary model fitted with `nonlinear =` the per-parameter figures reach
126 and a check that gated on them would refuse every spline model. This
is the requirement `inst/capability-matrix.md` finding 3 had already
stated, before any collinearity function existed to meet it. A genuinely
duplicated predictor is still refused.

`_pkgdown.yml` now lists every documented topic, and
`test-pkgdown-index-complete.R` keeps it that way in both directions.
The site build had been failing since the accessors were added: a
curated reference index is the one artefact that using the package
cannot check, so twelve topics had accumulated unlisted, the oldest for
weeks.

Outcome coercion in all of these goes through
[`mm_event_indicator()`](https://mufflyt.github.io/mysterymodel/reference/mm_event_indicator.md),
the rule the rest of the package uses, rather than the private rule the
originals carried: a bare
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) turns a No/Yes
factor into 1 and 2, and two conventions would let a cohort be fitted
one way round and recalibrated the other with nothing saying so.
[`mm_check_positive()`](https://mufflyt.github.io/mysterymodel/reference/mm_check_positive.md)
refuses a declared event level the outcome does not carry, which
[`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md)
already does for everything that goes through a project but which these
entry points accept directly.

Two functions were deliberately not ported: `mm_logit()`, a clamped
variant no ported function needed here, and `mm_recal_axis()`, which is
bound to the source project’s held-out cycles and artefact layout.

### Refusing what cannot be meant

- A predictor that reproduces the outcome, or its exact complement, is
  refused by
  [`mm_leakage()`](https://mufflyt.github.io/mysterymodel/reference/mm_leakage.md).
  Separation that is not duplication is reported instead, because in a
  small cohort it can be real. A strong but non-deterministic
  association is not mentioned at all
  ([\#13](https://github.com/mufflyt/mysterymodel/issues/13), DEC-004).
- [`mm_check_resamples()`](https://mufflyt.github.io/mysterymodel/reference/mm_check_resamples.md)
  refuses a fractional, missing, infinite or non-numeric resample count
  before any seed is set, rather than letting
  [`as.integer()`](https://rdrr.io/r/base/integer.html) turn 2.7 into 2
  ([\#13](https://github.com/mufflyt/mysterymodel/issues/13), DEC-004).
- [`mm_metrics()`](https://mufflyt.github.io/mysterymodel/reference/mm_metrics.md)
  refuses a predicted probability outside `[0, 1]` rather than clamping
  it, because a clamped 1.5 becomes a plausible Brier score
  ([\#13](https://github.com/mufflyt/mysterymodel/issues/13), DEC-004).
- Validating against a cohort that is not the one the model was fitted
  on is an error, checked by a hash of the modelling columns rather than
  a row count, and a reordering is refused too
  ([\#9](https://github.com/mufflyt/mysterymodel/issues/9)).
- A predictor that does not vary among the rows the model can be fitted
  to is refused by name, with the value it is stuck at. `rms` reached
  one inside `Design()` and stopped with “has \<2 category levels”,
  which gives the variable but not the reason, and says nothing at all
  for a constant continuous column. Found by running
  [`mm_calculator()`](https://mufflyt.github.io/mysterymodel/reference/mm_calculator.md)
  on the ENT applicant cohort: Step 1 moved from a graded score to
  pass/fail part-way through the application cycles, so in the
  development years the field is one value for all but a single
  applicant, and complete-case selection leaves it constant. The
  predictor is not useless, it is unusable on that side of the split,
  and the message says so by reporting how many values it takes across
  the rows supplied. The same guard names the two all-zero indicator
  columns in
  [`caret::GermanCredit`](https://rdrr.io/pkg/caret/man/GermanCredit.html),
  `Purpose.Vacation` and `Personal.Female.Single`, which were previously
  absorbed into the rank-deficiency message.

### Counting the sample that exists

- Every reported count describes the rows `rms` fitted, not the rows it
  was handed. The sample-size gate judged the larger, partly imaginary
  sample, which made it most lenient exactly where data is most
  incomplete ([\#6](https://github.com/mufflyt/mysterymodel/issues/6)).
- Which rows are modelled is decided once, before fitting, and the
  `datadist`, the fit and the prediction schema are all built from that
  frame. Left to `na.action` the three disagreed, and a value no fitted
  row carried came back labelled as interpolation while the drawn
  nomogram reached axis values the model was never estimated on
  ([\#7](https://github.com/mufflyt/mysterymodel/issues/7)).
- [`mm_evaluable()`](https://mufflyt.github.io/mysterymodel/reference/mm_evaluable.md)
  is the one eligibility rule, read by fitting and by both kinds of
  validation. A missing predictor, a missing outcome and the overlap are
  counted apart, because taking a missing outcome for a non-event leaves
  the event count unchanged while inflating the denominator
  ([\#8](https://github.com/mufflyt/mysterymodel/issues/8), DEC-003).
- A factor level carried only by dropped rows is removed and named in
  `lost_levels`, since `rms` answers one with a singular Hessian that
  identifies neither the variable nor the level
  ([\#7](https://github.com/mufflyt/mysterymodel/issues/7)).

### Patient data

- The model carries no copy of the cohort. A formula keeps the
  environment it was built in and
  [`rms::lrm()`](https://rdrr.io/pkg/rms/man/lrm.html) stores that on
  `fit$terms` and `fit$sformula`, so a model built the default way held
  the whole cohort, patient identifiers included, into anything that
  saved it. The formula is built in
  [`baseenv()`](https://rdrr.io/r/base/environment.html)
  ([\#5](https://github.com/mufflyt/mysterymodel/issues/5)). The fitted
  model went from 176.5 KB to 36.1 KB and 500 planted identifiers to
  none, with the coefficient fingerprint unchanged.
- [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
  requires `newdata`, so no patient-level original is retained and no
  stored copy can drift from the data the caller has
  ([\#3](https://github.com/mufflyt/mysterymodel/issues/3)).
- The cost of the empty formula environment is now written down rather
  than met one package at a time. `emmeans`, `marginaleffects`,
  `effects`, `sjPlot`, `DynNom` and `regplot` all fail on these fits,
  for that one reason (DEC-015). `rms` is unaffected because it reads
  the stored `x`, `y` and `datadist`. The trade is kept.

### The front end

- [`mm_calculator()`](https://mufflyt.github.io/mysterymodel/reference/mm_calculator.md)
  builds a Shiny calculator from `model$schema`: a dropdown offering the
  levels the model was developed on and no others, a number defaulting
  to the median the `datadist` recorded and stating the development
  range, and scoring through
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
  (DEC-016). Because the inputs and the scoring are read from the one
  schema the fit recorded, they cannot drift apart, and the startup
  schema validator that a hand-built calculator needs has nothing to
  check.
- The screen carries what the number rests on, not only the number: a
  gauge whose sweep ends at four times the reference rather than at
  100%, the risk as a count out of a hundred figures, the band’s
  reference printed beside the band, the adequacy verdict with its
  reason where it cannot be missed, and the coefficient fingerprint. A
  value outside the development range raises an alert on the face of the
  page rather than being clamped to the limit, which is what the
  `UTI_Calculator` this is modelled on did.
- Bands are cut on the odds ratio against a reference that defaults to
  the development cohort’s own event rate, because that is the only
  threshold a fitted model carries. A decision threshold from a decision
  curve goes in through `threshold`. Either way the page names both the
  reference and the odds ratio.
- The cut points are odds ratios and not multiples of the probability
  because multiples stop working as soon as the outcome is common. On
  the ENT applicant cohort, where 62.4% of applicants matched, twice the
  reference is not a probability: every applicant above the reference
  fell into one band and the top two could not be reached at all. A
  logistic model is linear in the log odds, so a band on the odds ratio
  is a band on the scale the model works in, and all four bands are
  populated at a 9% event rate and at a 62% one alike.
- `higher_is` says whether a higher prediction is the bad outcome or the
  good one, and decides which way round the colours and the gauge
  gradient run. A model predicting a complication and a model predicting
  a successful match are the same object to the package, and painting a
  high chance of matching red would be the package guessing. The label
  stays directional either way.
- It is built here because nothing in the ecosystem can be trusted with
  these fits. `DynNom` refits the model it is handed: adding 0.5 to the
  `age` coefficient left its predictions unmoved while `rms` moved by
  9.5, and handing it the whole cohort for a model developed on a
  temporal split, 404 of 600 rows, moved the linear predictor by 0.130
  and the risk by 0.018 with nothing said. `regplot` has no `data`
  argument at all (DEC-016).
- The nomogram is on the page, below the calculator, and
  [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
  is what draws it. That matters more than it looks: the sheet does not
  appear unless reading it back the way a clinician reads it reproduces
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md),
  so the figure and the number beside it are checked against each other
  rather than merely resembling each other. The panel prints the
  agreement it was granted on, the bound on reading between ticks, and
  any mutually exclusive axes. A model that cannot be drawn says why in
  place of the figure.
- An [`Hmisc::label()`](https://rdrr.io/pkg/Hmisc/man/label.html) on the
  cohort now reaches the nomogram’s axes and the calculator’s form
  alike. `rms` already carried labels onto a drawn sheet, but
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  lost them for factors:
  [`droplevels()`](https://rdrr.io/r/base/droplevels.html),
  [`factor()`](https://rdrr.io/r/base/factor.html) and
  [`relevel()`](https://rdrr.io/r/stats/relevel.html) each drop the
  attribute a label lives in, so a fully labelled cohort produced a
  sheet whose continuous axes read as English and whose categorical ones
  read as column names. The label is preserved across those calls and
  recorded in the schema, so one predictor cannot be captioned two ways
  on one page. An unlabelled predictor keeps its column name.
- [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
  gained `labels`, for relabelling a model that is already fitted. The
  renaming happens after the sheet has been checked against
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
  and never before: the check matches axes to predictors by the names
  the fit gave them, so a caption cannot alter what was verified.
  Relabelled and plain sheets return identical agreement, profiles
  checked and reading error.
- The sheet is sized to the model. Height came from a fixed `height = 9`
  whatever the model, and a nomogram’s rows do not get shorter when
  there are more of them: the ENT model’s 27 axes on the 9 inches that
  suited 3 printed row labels across their own tick marks, and the sheet
  was drawn, verified and unreadable. Height now follows the row count
  with 9 inches as the floor, and width follows the longest printed
  name, which shares the left margin with every row’s leftmost tick
  label. `width` and `height` still take a figure when one is wanted,
  and are reported on the returned object.
- The risk axis is tick-marked in equal steps of the linear predictor
  rather than of probability. The sheet is drawn linear in the linear
  predictor, so equal steps of probability are not equal steps on paper:
  over the ENT model’s range the default nine ticks from 0.1 to 0.9
  landed inside a seventh of the axis and overprinted one another, on
  the one axis a reader takes the answer off. Ticks are now chosen in
  the linear predictor, converted, and rounded to figures somebody would
  write down.
- The README claimed pagination when a model outgrows one page. There is
  none and there will not be: a nomogram split across sheets makes a
  reader carry a running total between them. The page grows instead, and
  the claim is gone.
- [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
  gained `funlabel`. The printed risk axis was hardcoded to “Predicted
  risk”, which is the wrong noun on a sheet about a chance of matching
  handed to the person it is about.
- `audience` says who is reading: a `"clinician"` scoring someone else,
  or the `"self"` the row is about, reading their own prediction. They
  need different instructions. A clinician needs to be told the number
  is not advice and that the model cannot see the person in front of
  them; an applicant reading their own chance of matching needs to be
  told that the model describes people who share their values and not
  them, that a number is not a verdict, and that it was fitted on people
  who came before them. The clinical page handed to an applicant warns
  them about medical advice, which is both wrong and faintly absurd.
- `subject` names what one row is. Every sentence on the page uses it,
  so the ENT model’s calculator says applicant where a clinical one says
  patient. A page that warns an applicant about medical advice reads as
  though it were assembled from someone else’s calculator, which is the
  impression a tool asking to be trusted can least afford.
- The result column is sticky. With 27 predictors the form is far longer
  than its own result, and scrolling to the last of them left the
  prediction off the top of the screen with the right-hand half of the
  page empty. Bootstrap floats its columns, so the row is a flex
  container: without that the column is only as tall as its own content
  and a sticky child has nothing to stay inside.
- [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
  gained `interval` and `level`. The limits come from the standard error
  of the linear predictor at the supplied values, transformed, so the
  interval is asymmetric on the probability scale and cannot run past 0
  or 1. It is computed in a second call rather than by deriving `.pred`
  from the linear predictor, because the fitted value is what the rest
  of the package is checked against, the nomogram to 1e-16 among it, and
  an interval is not a reason to compute it a different way.
- **The calculator does not show that interval**, by owner decision on
  review finding `D-1`. It is parameter uncertainty on the probability
  scale, and a reader shown it beside one person’s risk would reasonably
  take it for the range that person’s own risk lies in, which is a wider
  quantity this package does not compute. The number is still computed,
  still returned by `mm_predict(interval = TRUE)` and still carried on
  each saved record; it is the display that was withdrawn, and the
  panel’s caveat now separates parameter, estimated-risk and prediction
  uncertainty by name rather than describing the one it used to print.
  An earlier draft of this entry said the calculator showed the
  interval, which is no longer true.
- Rows accumulate and are compared, which is the one idea worth taking
  from `DynNom`. A single prediction answers nothing; the question a
  reader has is what the number would be if one value were different.
  Kept rows are drawn against a common scale, each row’s estimate marked
  by a dot and hoverable for the values that produced it, and an
  extrapolated row says so. No uncertainty range is drawn beside a row,
  and the axis is scaled by the widest estimate rather than by a bound
  nothing draws. Drawn as positioned divs: `DynNom` reaches for
  `ggplot2`, `plotly` and `stargazer` to put eleven points on one axis,
  and a calculator that needs no graphics device is one that can be
  served anywhere.
- `gates` couples one input to another: a numeric predictor can be
  switched off by a categorical one and parked at the value the model
  was fitted with. A Step 2 CK score means nothing for an applicant who
  has not sat Step 2, and a form that accepts “not reported” beside a
  score of 250 submits a combination the model was never fitted on. The
  control is disabled inside a `fieldset` rather than removed, so the
  browser locks it while Shiny still submits the parked figure and the
  row stays complete; removing it would leave the predictor missing and
  the row unscorable, which is the opposite of the point. No JavaScript
  and no new dependency.
- Not taken from `DynNom`: sliders for continuous inputs, because a
  slider bounded to the development range makes extrapolation
  unreachable and this package allows it and labels it instead; and the
  model-summary tab, because the adequacy panel and the fingerprint
  already carry what a reader should act on.

### Tests and validation

- 318 test blocks carrying 1301 assertions across 25 files, including 41
  saboteurs verified to fire against deliberately disabled guards
  ([\#12](https://github.com/mufflyt/mysterymodel/issues/12),
  [\#26](https://github.com/mufflyt/mysterymodel/issues/26)), a leakage
  suite ([\#13](https://github.com/mufflyt/mysterymodel/issues/13)), and
  a discrimination-interval suite that checks every degenerate case
  against an independent `pROC` call rather than a recorded number
  ([\#19](https://github.com/mufflyt/mysterymodel/issues/19)).
- Validated against eleven cohorts from outside the package, with every
  reported number traced to the engine or the hand calculation that owns
  it. How, against what and to what tolerance is in
  `inst/validation-appendix.md`; provenance, licences and checksums are
  in `inst/benchmarks.md`.
- Six defects were found there that the package’s own fixtures could not
  reach, four of them cases where a default was doing the deciding: a
  plan inherited through `NULL`
  ([\#26](https://github.com/mufflyt/mysterymodel/issues/26)), a factor
  level chosen by sort order
  ([\#26](https://github.com/mufflyt/mysterymodel/issues/26)), and a
  bootstrap seed pinned by design
  ([\#26](https://github.com/mufflyt/mysterymodel/issues/26)).

### Simplification

- An audit for over-engineering produced thirteen findings; seven were
  implemented, one partly, and five retained on evidence
  ([\#16](https://github.com/mufflyt/mysterymodel/issues/16),
  [\#17](https://github.com/mufflyt/mysterymodel/issues/17),
  [\#18](https://github.com/mufflyt/mysterymodel/issues/18), DEC-005).
  `pROC` was kept because
  [`Hmisc::rcorr.cens()`](https://rdrr.io/pkg/Hmisc/man/rcorr.cens.html)
  returns an interval where DeLong correctly reports that none is
  estimable, and the capability spike was kept because it still
  reproduces its matrix exactly. No reported number moved.
