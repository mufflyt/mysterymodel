# The fewest resamples a bootstrap correction may be averaged over

Four fifths of the resamples requested. Both bootstraps apply it: `rms`
keeps only the resamples that fitted and the full-process loop counts
its own failures, and an optimism averaged over the survivors of a
selection nobody reported is not the quantity it claims to be.

## Usage

``` r
mm_min_resamples(B)
```

## Arguments

- B:

  Resamples requested.

## Value

The fewest that must have fitted.
