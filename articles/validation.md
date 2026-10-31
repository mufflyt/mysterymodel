# Which number are you reporting?

``` r

library(mysterymodel)
```

A clinical prediction paper reports a c-statistic. There are at least
four different quantities with that name available from one fitted
model, they differ by more than the rounding a manuscript shows, and
nothing in the number itself says which one it is.
[`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md)
returns all of them, one per row, labelled, so that choosing is a
decision someone makes rather than a default nobody noticed.

``` r

cohort <- mm_synthetic_cohort(n = 600, prevalence = 0.11, seed = 1978)

project <- mm_project("uds", "event",
                      c("age", "bmi", "sex", "prior_uti"),
                      positive_class = 1, cohort = cohort,
                      split_var = "year", split_at = 2023,
                      cluster_id = "pid", seed = 1978)

model <- suppressWarnings(
  mm_model(project, cohort, nonlinear = "age",
           interactions = list(c("prior_uti", "sex"))))

validation <- mm_validate(model, cohort, B = 100, full_process = TRUE)
validation$metrics[, c("basis", "n", "events", "c_stat", "cal_slope",
                       "brier")]
#>                     basis   n events    c_stat cal_slope      brier
#> 1                apparent 404     45 0.6647478        NA 0.09391697
#> 2  bootstrap, fixed model 404     45 0.6067696 0.7126282         NA
#> 3 bootstrap, full process 404     45 0.6065333 0.7074585 0.09828239
#> 4                held out 196     22 0.7857889 1.7369817 0.08482979
```

## The four bases

**Apparent** is the model scored on the rows it was fitted to. It is
always optimistic, and it is reported here so that the optimism is
visible rather than absent.

**Bootstrap, fixed model** comes from
[`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html). Each
resample refits the same formula, which corrects the optimism of
*estimating coefficients*. It re-derives nothing the formula was shaped
by.

**Bootstrap, full process** refits the whole strategy inside every
resample: knot placement, `datadist` and factor-level handling are all
learned from the resample rather than inherited from the original fit.

**Held out** is the rows the project’s split reserved, scored once.

Two cells are empty, for two different reasons, and both are the right
answer.

The `brier` cell on the fixed-model row is empty because
[`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html) returns
Somers’ Dxy and the calibration slope, not a Brier score. Carrying the
apparent Brier across into that row would make it look corrected when
nothing corrected it.

The scaled Brier gets the same treatment one step further on. It is a
score against a reference, and left alone each basis would use its own
prevalence, so a column of them would be scores against different
references. Every basis here is scaled against the development cohort’s
reference, reported as `brier_ref`, and a basis with a prevalence of its
own keeps that value in its `note`:

``` r

validation$metrics[, c("basis", "brier", "brier_ref", "brier_scaled")]
#>                     basis      brier  brier_ref brier_scaled
#> 1                apparent 0.09391697 0.09897927  0.051144980
#> 2  bootstrap, fixed model         NA         NA           NA
#> 3 bootstrap, full process 0.09828239 0.09897927  0.007040662
#> 4                held out 0.08482979 0.09897927  0.142953979
```

The `cal_slope` cell on the **apparent** row is empty because that
number is an identity rather than an estimate. Scoring an unpenalized
maximum-likelihood fit on the very rows that produced it forces the
calibration intercept to zero and the slope to one: they are the fit’s
own score equations rearranged. Printed beside a held-out slope they
read as the model being perfectly calibrated, which is the one thing
they cannot show. You can watch them be exactly that:

``` r

y <- as.integer(model$fit$y)
lp <- as.numeric(model$fit$linear.predictors)
c(intercept = unname(coef(glm(y ~ 1, family = binomial(), offset = lp))[1]),
  slope     = unname(coef(glm(y ~ lp, family = binomial()))[2]))
#>    intercept        slope 
#> 8.172466e-17 1.000000e+00
```

The package detects the identity rather than assuming it, so a fitting
method that does not force it, a penalized fit for instance, would have
its apparent calibration reported as the estimate it would then be.

``` r

parts <- mysterymodel:::mm_split(project, cohort)
c(development = nrow(parts$dev), held_out = nrow(parts$held))
#> development    held_out 
#>         404         196
range(parts$dev$year)
#> [1] 2019 2022
range(parts$held$year)
#> [1] 2023 2024
```

One function owns the split, so fitting, validation and held-out scoring
cannot disagree about which rows are development. A row with a missing
`year` falls on neither side, and is an error rather than a silent drop.

## What the full process does and does not cover

This is the distinction the package will not let a caller skip. The
detail object names what was actually repeated:

``` r

detail <- validation$full_process_detail
detail$covers
#> [1] "knot placement" "datadist"       "factor levels"
cat(detail$note, "\n")
#> full-process bootstrap, 100 of 100 resamples valid. Re-derives knots, datadist and factor levels per resample; imputation, selection and tuning are not in this pipeline yet. Resampled by whole pid. The correction is a mean over resamples and carries a Monte Carlo standard error of 0.00441 on the c-statistic and 0.02021 on the slope, so these figures are determined to about 2 decimal place(s) and not to as many as they print with
```

`covers` is a list that will grow. Imputation, selection, tuning and
interaction screening are not re-executed, because the package does not
do them yet. A strategy including any of them is not fully validated by
this function either, and saying so in the returned object is what keeps
the claim honest as the pipeline grows.

The optimism and the correction are both available, rather than only
their difference:

``` r

round(rbind(apparent  = unlist(detail$apparent[names(detail$optimism)]),
            optimism  = detail$optimism,
            corrected = detail$corrected), 4)
#>           c_stat cal_intercept cal_slope   brier brier_scaled
#> apparent  0.6647             0    1.0000  0.0939       0.0511
#> optimism  0.0582             0    0.2925 -0.0044       0.0441
#> corrected 0.6065             0    0.7075  0.0983       0.0070
```

Those two calibration numbers in the `apparent` row are the identity
again, and here they are load bearing rather than misleading: an
in-sample slope that is exactly one in every resample is what makes the
optimism of the slope equal to the mean out-of-sample shortfall, which
is the quantity the corrected row reports.

The scaled Brier in that table is derived, not differenced. It divides
by `rate * (1 - rate)` of whichever rows were scored, so an in-sample
value and an out-of-sample value are scaled by different constants and
their difference would carry that drift as well as the optimism. The
Brier itself is on one scale throughout, so it is corrected and the
scaled version is then computed from the corrected value against one
fixed denominator, the development cohort’s own no-information Brier:

``` r

c(no_information_brier = detail$no_information_brier,
  corrected_brier      = unname(detail$corrected[["brier"]]),
  derived_scaled       = unname(detail$corrected[["brier_scaled"]]),
  check = 1 - unname(detail$corrected[["brier"]]) /
    detail$no_information_brier)
#> no_information_brier      corrected_brier       derived_scaled 
#>          0.098979267          0.098282387          0.007040662 
#>                check 
#>          0.007040662
```

On a cohort of 150 that correction moved the reported number from -0.024
to -0.040, so it is not a rounding matter.

Resamples that cannot be fitted are counted, not dropped quietly:

``` r

c(valid = detail$valid, of = detail$B)
#> valid    of 
#>   100   100
detail$adequate
#> [1] TRUE
detail$failures
#> character(0)
```

A resample that separates, or that is missing a factor level, is a real
feature of a small cohort. An optimism averaged over the survivors of a
selection nobody reported is not the quantity it claims to be, so the
count is part of the result and `adequate` is `FALSE` when too few
fitted.

## One caution about comparing the two bootstrap rows

They look comparable and are not. The fixed-model row derives its
c-statistic from `rms`‘s Somers’ Dxy as `0.5 + Dxy / 2`; the
full-process row is a mean of `pROC` AUCs over resamples. Two estimators
of the same population quantity differ a little by construction, so a
small gap between those two rows carries no information about the
modelling strategy. Compare each against **apparent**, which is the
comparison each was built to support.

## Resampling the patient rather than the row

The cohort has repeat visits. Resampling rows treats two visits by one
person as two independent facts, and that narrows every interval it
touches.

``` r

dev <- parts$dev
by_row     <- mysterymodel:::mm_resample(dev, cluster_id = NULL)
by_patient <- mysterymodel:::mm_resample(dev, cluster_id = "pid")

c(rows_in_cohort = nrow(dev),
  row_draw       = length(by_row),
  patient_draw   = length(by_patient))
#> rows_in_cohort       row_draw   patient_draw 
#>            404            404            405
```

A row draw always has exactly as many rows as the cohort. A patient draw
has as many *patients*, so its row count varies with which patients were
drawn, and a patient contributing two visits brings both or neither.

Here is the property that matters, stated as a check rather than as a
claim. Take the patients with exactly two visits, and count how many
rows each of them contributes to the draw:

``` r

drawn <- dev[by_patient, ]
twins <- names(which(table(dev$pid) == 2L))
rows_drawn <- table(factor(drawn$pid, levels = twins))

table(rows_drawn %% 2L)
#> 
#>  0 
#> 22
range(rows_drawn)
#> [1] 0 4
```

Every count is even. A patient drawn once brings two rows, a patient
drawn twice brings four, a patient not drawn brings none. No single
visit is ever separated from its sibling, which is what makes the
resample a draw of patients rather than a draw of rows wearing patient
labels.

The project declares `cluster_id = "pid"`, so both bootstraps draw
patients:

``` r

validation$clustered_by
#> [1] "pid"
validation$fixed_model$clustered_by
#> [1] "pid"
```

That second one was this package’s own omission for a while, and the
note used to blame `rms` for it.
[`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html) passes
its extra arguments through to
[`rms::predab.resample()`](https://rdrr.io/pkg/rms/man/predab.resample.html),
which takes a `cluster` and draws whole units when it is given one, so
nothing but the missing argument was stopping it.

``` r

cat(strwrap(validation$metrics$note[validation$metrics$basis ==
                                    "bootstrap, fixed model"], 72), sep = "\n")
#> rms::validate, 100 of 100 resample(s) fitted. Refits the same formula;
#> does not re-derive knots or levels. Resampled by whole pid. No
#> interval: DeLong describes an apparent c-statistic, not a corrected
#> one, and an interval for the corrected index needs a nested bootstrap
#> that is not implemented here
```

The resample count in that note is the number `rms` actually fitted, not
the number asked for. `predab.resample()` keeps only the resamples that
converged and mentions the shortfall only when `pr = TRUE`, which
`validate.lrm` leaves off, so a corrected index can be an average over
the resamples that happened to work with nothing on the object to say
so. The count comes back as the `n` column, and falling below four
fifths of `B` is reported as inadequate, the same threshold the
full-process row uses.

## Scoring any set of predictions

The metric helper that produces each row is usable on its own, which is
how a calibration or subgroup table gets the same arithmetic as the main
table instead of a second implementation of it:

``` r

y <- mysterymodel:::mm_event_indicator(parts$held$event, 1)
p <- mm_predict(model, parts$held)$.pred

by_hand <- mysterymodel:::mm_metrics(p, y, basis = "held out, by hand")
by_hand[, c("basis", "n", "events", "c_stat", "c_lower", "c_upper",
            "cal_intercept", "cal_slope")]
#>               basis   n events    c_stat   c_lower   c_upper cal_intercept
#> 1 held out, by hand 196     22 0.7857889 0.6770106 0.8945672   -0.05204503
#>   cal_slope
#> 1  1.736982
```

Those are the same numbers as the held-out row of the main table,
because it is the same function. One column is deliberately not the
same, and it is worth seeing why:

``` r

held_row <- validation$metrics[validation$metrics$basis == "held out", ]
c(main_table   = held_row$brier_scaled,
  main_ref     = held_row$brier_ref,
  by_hand      = by_hand$brier_scaled,
  by_hand_ref  = by_hand$brier_ref)
#>  main_table    main_ref     by_hand by_hand_ref 
#>  0.14295398  0.09897927  0.14868833  0.09964598
```

A scaled Brier is a score against a reference, and a bare call uses the
reference of the rows it was given. The main table passes the
development cohort’s reference to every basis instead, so that reading
down the column compares like with like. A subgroup table wants the bare
behaviour, since each subgroup’s own skill score is the question being
asked there.

## By subgroup

``` r

held <- parts$held
held$.p <- p
held$.y <- y

do.call(rbind, lapply(split(held, held$sex), function(g)
  mysterymodel:::mm_metrics(g$.p, g$.y, basis = as.character(g$sex[1]))[
    , c("basis", "n", "events", "c_stat", "cal_slope")]))
#>         basis   n events    c_stat cal_slope
#> female female 142     11 0.6932686  1.421728
#> male     male  54     11 0.8456660  2.062632
```

Read those with the event counts beside them. A c-statistic from a few
dozen events is compatible with a wide range of truths, and the interval
columns are in the full return value for exactly that reason.

## What the interval is, and the three rows that do not have one

The interval on a c-statistic is DeLong’s, from `pROC`, and it describes
the c-statistic of **one model scored once on one sample**. Two of the
four rows in the table above are not that.

``` r

validation$metrics[, c("basis", "n", "events", "non_events",
                       "c_stat", "c_lower", "c_upper")]
#>                     basis   n events non_events    c_stat   c_lower   c_upper
#> 1                apparent 404     45        359 0.6647478 0.5749341 0.7545614
#> 2  bootstrap, fixed model 404     45        359 0.6067696        NA        NA
#> 3 bootstrap, full process 404     45        359 0.6065333        NA        NA
#> 4                held out 196     22        174 0.7857889 0.6770106 0.8945672
```

The bootstrap rows carry no interval, and the reason is in their notes
rather than left as a pair of blanks:

``` r

cat(strwrap(validation$metrics$note[
  validation$metrics$basis == "bootstrap, fixed model"], 72), sep = "\n")
#> rms::validate, 100 of 100 resample(s) fitted. Refits the same formula;
#> does not re-derive knots or levels. Resampled by whole pid. No
#> interval: DeLong describes an apparent c-statistic, not a corrected
#> one, and an interval for the corrected index needs a nested bootstrap
#> that is not implemented here
```

A corrected index is an apparent one minus an average optimism. Neither
[`rms::validate()`](https://rdrr.io/pkg/rms/man/validate.html) nor the
full-process loop returns the distribution of that difference, so there
is nothing to put an interval around; the recognised answer is a nested
bootstrap, which costs `B` times the correction and is not implemented
here. What must not happen is the apparent row’s interval being read
down the column as though it applied to the corrected estimate, which is
why the blanks are annotated.

Two more cases are reported rather than hidden. DeLong needs at least
two of each outcome, so a cohort with one event gets its c-statistic and
no interval:

``` r

one_event <- mysterymodel:::mm_metrics(
  c(0.9, seq(0.1, 0.5, length.out = 40)), c(1, rep(0, 40)),
  basis = "one event")
#> Warning: glm.fit: algorithm did not converge
#> Warning: glm.fit: fitted probabilities numerically 0 or 1 occurred
one_event[, c("n", "events", "non_events", "c_stat", "c_lower")]
#>    n events non_events c_stat c_lower
#> 1 41      1         40      1      NA
cat(strwrap(one_event$note, 72), sep = "\n")
#> the c-statistic has no interval here, which needs at least two of each
#> outcome, and there are 1 event(s) and 40 non-event(s). the calibration
#> slope is withheld: the fit behind it did not converge, so its
#> coefficient marks where iteration stopped rather than an estimate
```

And where the classes separate completely, DeLong’s standard error is
zero, so the interval it returns has zero width. That is the estimator
running out of information, not a precise answer, and the note says so
rather than leaving `1.000 to 1.000` on the page:

``` r

separated <- mysterymodel:::mm_metrics(
  c(seq(0, 0.4, length.out = 30), seq(0.6, 1, length.out = 30)),
  rep(0:1, each = 30), basis = "separated")
#> Warning: glm.fit: algorithm did not converge
#> Warning: glm.fit: fitted probabilities numerically 0 or 1 occurred
cat(strwrap(separated$note, 72), sep = "\n")
#> 95% DeLong interval, from 30 event(s) and 30 non-event(s). that
#> interval has zero width, which is what DeLong returns when the classes
#> separate completely or every prediction ties: the estimator has no
#> information left to spend on an interval, so this is not a statement of
#> precision. the calibration slope is withheld: the fit behind it did not
#> converge, so its coefficient marks where iteration stopped rather than
#> an estimate
```

No threshold on the event count is applied anywhere in this. There is no
evidence in this package for a universal minimum, so instead every row
states the method and the two counts its standard error is computed
from, and a reader judges the three-event interval for themselves.

## Rows that cannot be judged

The cohort above is complete. A real external cohort is not, and the two
ways it is incomplete are not the same thing.

``` r

holey <- cohort
held_rows <- which(holey$year >= 2023)
holey$bmi[1:25] <- NA                      # development, a missing predictor
holey$bmi[held_rows[1:9]] <- NA            # external, a missing predictor
holey$event[held_rows[20:27]] <- NA        # external, a missing outcome
holey$bmi[held_rows[26:30]] <- NA          # and the overlap of the two

holey_model <- suppressWarnings(
  mm_model(project, holey, nonlinear = "age",
           interactions = list(c("prior_uti", "sex"))))
holey_validation <- suppressWarnings(
  mm_validate(holey_model, holey, B = 50, full_process = TRUE))

holey_validation
#> <mm_validation>  full-process: TRUE
#>   columns: n, events/non-events, c-statistic with its 95% DeLong interval where one is estimable
#>   apparent                 n=389   43/346 C=0.6605 (0.5669-0.7541)
#>   bootstrap, fixed model   n=389   43/346 C=0.5894 no interval, see note  slope=0.6522
#>   bootstrap, full process  n=389   43/346 C=0.5971 no interval, see note  slope=0.6921
#>   held out                 n=175   19/156 C=0.7702 (0.6491-0.8914)  slope=1.6426
#>   development eligibility: 389 of 404 scored, 15 missing a predictor, 0 missing the outcome, 0 both
#>   held out eligibility: 175 of 196 scored, 13 missing a predictor, 6 missing the outcome, 2 both
#>   Full process re-derives knot placement, datadist, factor levels per resample; 50 of 50 valid.
#>   Its correction carries a Monte Carlo standard error of 0.00632 on C; rms does not return
#>   the per-resample values its own row is averaged over, so the
#>   same figure cannot be given for the fixed-model row.
```

``` r

str(holey_validation$eligibility$held_out)
#> List of 7
#>  $ n_total          : int 196
#>  $ n_scored         : int 175
#>  $ n_excluded       : int 21
#>  $ missing_predictor: int 13
#>  $ missing_outcome  : int 6
#>  $ missing_both     : int 2
#>  $ by_variable      : Named int [1:2] 15 8
#>   ..- attr(*, "names")= chr [1:2] "bmi" "event"
```

A patient missing a predictor cannot be scored. A patient missing the
outcome can be scored but contributes nothing to a performance estimate.
They are counted apart, with the overlap separately, because collapsing
them hides which and because the specific error worth preventing is
quietly taking a missing outcome for a non-event: that leaves the event
count unchanged while inflating the denominator, so every reported risk
comes out low and nothing in the table looks wrong.

``` r

held <- holey[holey$year >= 2023, ]
row <- holey_validation$metrics[holey_validation$metrics$basis == "held out", ]
c(rows_in_the_held_out_period = nrow(held),
  rows_scored                 = row$n,
  events_among_them           = row$events)
#> rows_in_the_held_out_period                 rows_scored 
#>                         196                         175 
#>           events_among_them 
#>                          19
```

The bootstraps resample the fitted cohort and not the frame it was
handed, so a resample’s composition does not depend on how much of it
was missing:

``` r

c(supplied = holey_model$n_supplied,
  fitted   = holey_model$n_dev,
  resampled_by_the_full_process =
    holey_validation$full_process_detail$eligibility$n_scored)
#>                      supplied                        fitted 
#>                           404                           389 
#> resampled_by_the_full_process 
#>                           389
```

And the caveat travels with the number rather than living in a methods
section:

``` r

cat(strwrap(row$note, 72), sep = "\n")
#> year >= 2023, scored once. 175 of 196 row(s) scored, 21 excluded (13
#> for a missing predictor, 6 for a missing outcome, 2 for both; bmi 15,
#> event 8). Complete case, so these estimates assume the exclusions are
#> uninformative, which is an assumption and not a finding. 95% DeLong
#> interval, from 19 event(s) and 156 non-event(s). the scaled Brier is
#> taken against the reference 0.09832, not this sample's own 0.09678, so
#> the column compares like with like; against its own it would read
#> 0.1370
```

That last sentence is the point. Complete-case analysis is a
computational strategy, not a guarantee. Missingness can be informative,
the more so in a cohort this size, so the exclusions are disclosed
everywhere they apply instead of being summarised away. Multiple
imputation is the answer and is not in this package yet;
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
keeps refusing to put a number on an incomplete record in the meantime.

## Two input contracts

A bootstrap count is a count. `B = 2.7` used to run two resamples, which
answers a question nobody asked, so it is refused along with `NA`,
`NaN`, either infinity, a vector, a string and anything below one. A
count written with a decimal point is still a count, so `200.0` is fine.
The check runs before any seed is set, so a refused call leaves the
random-number state as it found it.

``` r

mm_validate(model, cohort, B = 2.7)
#> Error:
#> ! `B` is 2.7, which is not a whole number of resamples. Truncating it to 2 would answer a question that was not asked.
```

A predicted probability is a probability.
[`mm_metrics()`](https://mufflyt.github.io/mysterymodel/reference/mm_metrics.md)
used to clamp its input to the interior of `[0, 1]`, so a predicted risk
of 1.5 became a Brier score of 0.18 and whatever produced the 1.5 stayed
invisible.

``` r

mysterymodel:::mm_metrics(c(1.5, 0.4, 0.6), c(1L, 0L, 1L), basis = "probe")
#> Error:
#> ! predicted probabilities must be finite and within [0, 1]. Found 1 invalid value(s); row 1 is 1.5.
```

Zero and one are valid probabilities. Their logits are infinite and the
calibration terms are fitted on the logit scale, so a nudge survives on
that one line and nowhere else: the Brier and the c-statistic read the
probabilities as given.

``` r

edge <- mysterymodel:::mm_metrics(c(0, 1, 0.4, 0.6), c(0L, 1L, 1L, 0L),
                                  basis = "probe")
c(brier_reported = edge$brier,
  brier_by_hand  = mean((c(0, 1, 0.4, 0.6) - c(0L, 1L, 1L, 0L))^2),
  slope_estimable = !is.na(edge$cal_slope))
#>  brier_reported   brier_by_hand slope_estimable 
#>            0.18            0.18            1.00
```

## The honest summary

A fingerprint ties a validation result to the fit that produced it, so a
table cannot drift from its model without the pairing changing:

``` r

identical(validation$fingerprint, model$fingerprint)
#> [1] TRUE
substr(validation$fingerprint, 1, 16)
#> [1] "92df44fff5c5dae3"
```

Report the held-out row when a split exists, the full-process row when
it does not, the apparent row beside either so the optimism is visible,
and the `note` column verbatim in the supplement.
