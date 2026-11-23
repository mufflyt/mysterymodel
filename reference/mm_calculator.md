# A calculator for exactly this fitted model

Builds a Shiny application from the model's own prediction schema: one
input per predictor, a dropdown for a categorical one offering only the
levels the model was developed on, a number for a continuous one
defaulting to the median the `datadist` recorded and stating the range
it was developed on. Scoring goes through
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md),
so the calculator agrees with the model by construction rather than by
comparison.

## Usage

``` r
mm_calculator(
  model,
  title = NULL,
  subtitle = NULL,
  threshold = NULL,
  higher_is = c("worse", "better"),
  subject = "patient",
  audience = c("clinician", "self"),
  event = NULL,
  gates = NULL,
  nomogram = TRUE
)
```

## Arguments

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- title:

  The heading. Defaults to the outcome the model predicts.

- subtitle:

  A line under the heading. Defaults to the project slug and the
  predictors.

- threshold:

  The risk the bands are taken relative to. The default is the
  development cohort's own event rate, which is the only threshold a
  fitted model carries; a decision threshold from a decision-curve
  analysis belongs here when there is one. Whatever it is, the screen
  says so, because a band shown without the number it is relative to is
  not interpretable.

- higher_is:

  Whether a higher prediction is the `"worse"` outcome, as it is for a
  complication, or the `"better"` one, as it is for a chance of
  matching. It decides which way round the colours and the gauge
  gradient run. The model cannot know this and the package will not
  guess: the default is `"worse"`, because this is a risk calculator.
  The band's label stays directional either way, so the colour is never
  the only carrier.

- subject:

  What one row is, in the singular. A clinical model scores a
  `"patient"`, which is the default; the ENT applicant model this was
  first run against scores an `"applicant"`. It is a word, not
  decoration: every sentence on the page uses it, and a page that calls
  an applicant a patient reads as though it were written for a different
  model.

- audience:

  Who the page is written for: a `"clinician"` scoring someone else, or
  the `"self"` the row is about, reading their own prediction. It
  changes the instructions, which are the part of a calculator a reader
  is most likely to act on. An applicant reading their own chance of
  matching needs to be told that the model describes people who share
  their values rather than them; a clinician does not need that and does
  need to be told the number is not advice.

- event:

  What the outcome is, in the past tense, as it would complete "of 100
  applicants, 15 \_\_\_". The default is the outcome column's name,
  which is right when the column is named for what happened (`matched`)
  and wrong when it is not. It is read by the sentences the page writes
  for the person the prediction is about, where "had the outcome" is the
  kind of phrasing that tells a reader this page was not written for
  them.

- gates:

  Inputs that another input switches off, as a named list: each name is
  a numeric predictor and each element gives `by` (the categorical
  predictor that controls it), `when` (the level at which it is switched
  off) and optionally `value` (what it reads while off, defaulting to
  the median the `datadist` recorded). A Step 2 score means nothing for
  an applicant who has not sat Step 2, and a form that accepts "not
  reported" beside a score of 250 submits a combination the model was
  never fitted on.

- nomogram:

  Whether to draw the model's nomogram onto the page. The sheet comes
  from
  [`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md),
  so it is the verified one: it does not appear unless reading it back
  the way a clinician reads it reproduces
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md).
  A model that cannot be drawn says why in place of the figure rather
  than leaving the panel empty.

## Value

A [`shiny::shinyApp()`](https://rdrr.io/pkg/shiny/man/shinyApp.html)
object, which launches when printed.

## Details

This is here because the ecosystem renderers could not be trusted with
these fits. `DynNom` refits the model it is handed, which means the
figures on screen come from coefficients re-estimated on whatever rows
it recovered and not from the ones that were reported. `regplot` has no
`data` argument at all. Both, together with `emmeans`,
`marginaleffects`, `effects` and `sjPlot`, also fail outright on a
[`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
because the formula is built in an empty environment and carries no
cohort to recover: see DEC-015 and `inst/capability-matrix.md`. A front
end over
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
reads the stored coefficients, refuses an unseen level by name and marks
a row outside the development range, which is the behaviour a clinical
calculator needs.

**No uncertainty range is shown beside the risk.**
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
computes one and this function still receives it, so nothing statistical
was removed, but it is not displayed: it is parameter uncertainty on the
probability scale, and a reader shown it beside one person's risk would
reasonably take it for the range that person's own risk lies in, which
is a wider quantity this package does not compute. The three
uncertainties are distinguished in the panel's own "Before you use this"
text, and the interval remains in the returned prediction and in each
saved record for anyone doing statistics rather than reading the screen.

This is the owner's resolution of review finding `D-1`, recorded in
`review/findings.csv`. Before it, this paragraph claimed no interval was
shown because
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
does not produce one; both halves of that were false, and the interval
was in fact rendered in three places. A regression test now fails if any
of them returns.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 300, seed = 1)
project <- mm_project("uds", "event", c("age", "bmi", "sex"),
                      cohort = cohort)
fit <- mm_model(project, cohort)
#> Warning: the development sample may be too small for this model: 300 rows is 26685 short of the 26985 a model of 3 parameter(s) needs at 9.3% prevalence for 90% shrinkage. Coefficients from a sample this size are expected to be overfitted; see the adequacy element of the returned object.
if (interactive() && requireNamespace("shiny", quietly = TRUE)) {
  mm_calculator(fit)
}
```
