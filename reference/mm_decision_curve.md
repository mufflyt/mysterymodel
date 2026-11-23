# Net benefit across treatment thresholds

Decision curve analysis. For each threshold probability the function
reports the net benefit of treating by the model, of treating everybody,
and of treating nobody, so the three can be read against each other.

## Usage

``` r
mm_decision_curve(
  obs,
  pred,
  thresholds = seq(0, 0.5, by = 0.01),
  positive = NULL
)
```

## Arguments

- obs:

  The observed outcome. Any column
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  accepts: 0/1, logical, or a two-level factor or character vector.

- pred:

  Predicted probabilities, for instance the `.pred` column of
  [`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md).

- thresholds:

  Threshold probabilities, in `[0, 1)`.

- positive:

  The level that means the event, passed to the same rule
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  uses. `NULL` infers it, and warns when it has to.

## Value

A data frame with one row per threshold: `threshold`,
`net_benefit_model`, `net_benefit_all`, `net_benefit_none`, and the `n`,
`n_dropped` and `prevalence` the curve was computed on.

## Details

A threshold is the probability at which a reader would opt for the
action. It carries the exchange rate between the two mistakes: at a
threshold of 0.1 a reader is saying one missed event costs about nine
unnecessary treatments, and the weight `t / (1 - t)` on false positives
below is that statement written as arithmetic.

The curve says which strategy has the highest net benefit over the range
of thresholds a reader might hold. It does not say the model is
calibrated, and it is not a substitute for
[`mm_validate()`](https://mufflyt.github.io/mysterymodel/reference/mm_validate.md):
a model can win on net benefit over a narrow band of thresholds and
still be systematically wrong about the level, which is what a
calibration intercept measures and what
[`mm_recal_intercept()`](https://mufflyt.github.io/mysterymodel/reference/mm_recal_intercept.md)
corrects.

**Computing a decision curve is not the same as being entitled to
publish one.** Net benefit is an explicit trade of a benefit against a
harm, so the curve means nothing until the decision-maker, the action
and the two outcomes being traded are named. This function supplies the
arithmetic and takes no view on whether that has been done.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 300, seed = 11)
project <- mm_project("dca", "event", c("age", "bmi"),
                      positive_class = 1, cohort = cohort)
fit <- suppressWarnings(mm_model(project, cohort))
scored <- mm_predict(fit, cohort)
curve <- mm_decision_curve(cohort$event, scored$.pred,
                           thresholds = seq(0, 0.3, by = 0.05),
                           positive = 1)
curve[, c("threshold", "net_benefit_model", "net_benefit_all")]
#>   threshold net_benefit_model net_benefit_all
#> 1      0.00       0.096666667     0.096666667
#> 2      0.05       0.049473684     0.049122807
#> 3      0.10       0.009259259    -0.003703704
#> 4      0.15       0.012352941    -0.062745098
#> 5      0.20       0.001666667    -0.129166667
#> 6      0.25      -0.003333333    -0.204444444
#> 7      0.30      -0.001428571    -0.290476190
```
