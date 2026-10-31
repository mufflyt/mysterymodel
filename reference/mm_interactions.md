# Test prespecified interactions, and report what the test rests on

Evaluates each candidate interaction as an addition to the project's
main-effects model and reports the evidence for it. It returns evidence
and nothing else: no model is modified, no term is added, and no
interaction reaches a nomogram because a p-value was small. Deciding
what the model contains stays with the analyst, which is what makes this
a diagnostic rather than a selection procedure.

## Usage

``` r
mm_interactions(
  project,
  cohort,
  candidates,
  test = c("LR", "Wald"),
  adjustment = c("none", "BH", "holm"),
  nonlinear = NULL,
  knots = 4L
)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- cohort:

  The cohort. Its development rows are used, under the same eligibility
  rule
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md)
  fits under, and the digest is checked so the screen cannot run on a
  different sample from the model.

- candidates:

  List of length-two character vectors naming the blocks to evaluate.
  Prespecified: this argument is a hypothesis, not a search.

- test:

  `"LR"` or `"Wald"`.

- adjustment:

  `"none"`, `"BH"` or `"holm"`.

- nonlinear, knots:

  Passed to
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md),
  because the shape of the model under test decides the degrees of
  freedom a block costs.

## Value

An object of class `mm_interaction_screen`.

## Details

Each candidate is one block tested against one reduced model, the
project's main effects. They are therefore `length(candidates)` separate
comparisons and not a sequence: a block is never tested against a model
containing another candidate, because that would make the answer depend
on the order they were listed in.

## What is reported, and what is withheld

A test is reported only for a block that is identifiable, which
[`mm_interaction_rank()`](https://mufflyt.github.io/mysterymodel/reference/mm_interaction_rank.md)
establishes from the design matrix before anything is fitted. A block
adding no dimension gets `NA` and a reason, never a p-value: such a
block produces a statistic near zero and a p-value near one, which reads
as evidence that the interaction is absent when it is evidence of
nothing at all.

Sparsity is reported beside the test and never withholds it. A
combination carrying no events leaves the design matrix at full rank, so
the interaction is estimable and the near-null result describes the
sparsity. Refusing the test there would also refuse the cohorts where an
interaction is real and small.

## The two tests

`test = "LR"` is a likelihood-ratio test from the difference in deviance
between the reduced fit and the fit with the block added, on verifiably
the same rows, cross-checked against
[`rms::anova.rms()`](https://rdrr.io/pkg/rms/man/anova.rms.html) with
`test = "LR"`. Both numbers are returned, and `lr_agrees` records
whether they match, so the claim is checked on every call rather than
once in a test file.

`test = "Wald"` is the joint Wald test of the whole block from
[`rms::anova.rms()`](https://rdrr.io/pkg/rms/man/anova.rms.html), which
is several degrees of freedom whenever a categorical or spline term is
involved. It is never the test of one dummy coefficient.

## Multiplicity, and what it does not fix

`adjustment` applies
[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) across the
candidates and the unadjusted value is always kept beside it. An
adjusted p-value addresses having looked at several blocks. It does not
address choosing a model from the result and then validating it on the
same data, which is optimism from selection and needs the selection
repeated inside the resampling. That is not in this function.

## Examples

``` r
cohort <- mm_synthetic_cohort(n = 600, prevalence = 0.15, seed = 1978)
project <- mm_project("uds", "event",
                      c("age", "bmi", "sex", "prior_uti"),
                      positive_class = 1, cohort = cohort)
mm_interactions(project, cohort,
                candidates = list(c("prior_uti", "sex"),
                                  c("age", "bmi")))
#> mm_interactions(): 2 prespecified block(s), LR test, multiplicity none
#> <mm_interaction_screen>  prespecified, LR test
#>   development 600 rows, 95 events, 4 parameter(s) before any block
#>   candidates  2 block(s) considered, 2 parameter(s) of candidate complexity in total
#>   prior_uti x sex        tested  chi2=3.917 df=1 p=0.0478
#>   age x bmi              tested  chi2=0.002 df=1 p=0.9645
#>   Evidence about blocks, not a model. Nothing here has been added to
#>   a model, and a small p-value is not a reason to add it: the
#>   optimism of choosing on these data is not corrected by this
#>   function.
```
