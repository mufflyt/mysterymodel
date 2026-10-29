# Draw one bootstrap resample, by patient when a cluster is declared

With repeated observations on the same patient, resampling rows treats
two visits by one person as two independent facts. That narrows every
interval it touches. When the project declares a cluster, whole patients
are drawn instead, which is what the specification's clustered design
asks for.

## Usage

``` r
cp_resample(cohort, cluster_id = NULL)
```

## Arguments

- cohort:

  Rows to resample.

- cluster_id:

  Column naming the patient, or `NULL` for row-level.

## Value

Integer row indices, with replacement.
