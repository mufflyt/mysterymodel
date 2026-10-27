# Generate a synthetic cohort resembling a urodynamics study

A cohort with known truth, for fixtures, examples and reports. The
public repository must never carry patient data, so every demonstration
in this package runs on this.

## Usage

``` r
cp_synthetic_cohort(
  n = 500,
  prevalence = 0.11,
  years = 2019:2024,
  repeat_frac = 0.08,
  seed = 1978L
)
```

## Arguments

- n:

  Rows to generate.

- prevalence:

  Target outcome prevalence. The default, with the default `n`, gives
  roughly the 57 events the specification describes for the reference
  study, which is the regime where degrees of freedom have to be spent
  carefully.

- years:

  Calendar years to spread the cohort over, for temporal validation.

- repeat_frac:

  Fraction of rows that are a second visit by a patient already present,
  so clustered resampling has something to cluster.

- seed:

  Single whole number.

## Value

A data frame of `n` rows with attribute `truth`, a list holding the true
coefficients and the generating formula.

## Details

The generating model is deliberately not a plain additive one. It
carries a nonlinear age effect and one interaction, because a pipeline
that is only ever exercised on additive data will not reveal whether its
spline and hierarchy handling are right.

The true coefficients are attached as the `truth` attribute, and the
intercept is solved numerically so the realised prevalence lands near
`prevalence` rather than wherever the other terms happen to put it.

## Examples

``` r
cohort <- cp_synthetic_cohort(n = 200, seed = 1)
table(cohort$event)
#> 
#>   0   1 
#> 181  19 
attr(cohort, "truth")$coefficients
#>     intercept        age_sq           bmi      sex_male prior_uti_yes 
#>     -2.867895      0.001100      0.045000      0.350000      0.800000 
#>   uti_by_male 
#>      0.600000 
```
