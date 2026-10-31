# Whether a fitted block has an estimate at all

Rank says whether the block is identifiable in the design matrix. This
asks the separate question of whether the likelihood has an interior
maximum, which it does not when the fitted values separate the outcome
completely: the coefficient then grows without bound as iteration
continues, and the statistic computed from where iteration happened to
stop is not a test of anything.

## Usage

``` r
mm_interaction_health(fitted, y)
```

## Arguments

- fitted:

  An
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- y:

  The 0/1 outcome of the rows it was fitted on.

## Value

A list: `converged`, `at_boundary`, `max_abs_coef`,
`complete_separation`, and a `note` describing what was found.

## Details

The test is exact rather than a tolerance. Complete separation of the
fitted values means every non-event is given less risk than every event,
so `max(p among non-events) < min(p among events)`. A model that is
merely very good does not satisfy it: some non-event always outranks
some event.

Quasi-separation, where only part of the sample is at the boundary, is
reported and not withheld. It makes an estimate fragile rather than
absent, and the counts say so.
