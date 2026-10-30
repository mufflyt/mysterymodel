# Look for predictors that carry the outcome rather than predict it

Three tiers, because they are three different findings and only one of
them is settled by arithmetic.

## Usage

``` r
mm_leakage(project, frame, y = NULL, min_overlap = 10L)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- frame:

  The development rows, after eligibility. Not modified.

- y:

  Optional 0/1 outcome for those rows, to avoid recomputing it.

- min_overlap:

  Fewest rows with both values observed for a verdict of duplication.
  Below this an exact match carries too little information to separate a
  copy from a coincidence, so the predictor is left alone.

## Value

A list of findings, each with `tier`, `predictor`, `kind`, `n_compared`,
`n_missing` and `detail`.

## Details

**Tier 1, duplication.** A predictor that reproduces the outcome on
every eligible row, or its exact complement. There is no cohort in which
that is a prediction, so it is an error.

**Tier 2, categorical separation.** Every observed level of a
categorical predictor falls in one outcome class. That can be leakage
and can equally be a small cohort, so it is reported for a human to
settle.

**Tier 3, numeric separation.** A threshold exists that separates the
classes completely. Same reasoning as tier 2.

A strong but non-deterministic association is not reported at all. A
correlation is what a predictor is for.

What this cannot do is worth stating, because the gap is where published
models go wrong: none of these tests says *when* a predictor was
measured. A variable recorded after the outcome, a treatment chosen
because of it, or a feature engineered from it can be weakly associated
and still be leakage. Checking availability at the moment of prediction
is the analyst's, and no comparison of columns can do it.
