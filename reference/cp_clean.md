# Apply eligibility rules and account for every row that leaves

Each rule is a named one-sided formula evaluated in the cohort. Rows
where it is `TRUE` continue; rows where it is `FALSE` are excluded and
attributed to that rule by name.

## Usage

``` r
cp_clean(cohort, rules = list(), label = "rows as supplied")
```

## Arguments

- cohort:

  The raw cohort.

- rules:

  Named list of one-sided formulas, each evaluating to a logical vector
  over `cohort`, as `~ age >= 40`. A formula is used rather than a bare
  expression so that nothing is evaluated before the cohort is in scope.
  The names become the ledger's labels, so they should read as the
  criterion they express.

- label:

  What the rows are, for the ledger's opening line.

## Value

An object of class `cp_cohort`, holding `data` and `ledger`.

## Details

The ledger is the point. A cohort count that cannot be reconciled
against the raw export is the commonest reason a published flow diagram
does not add up, so this function refuses to return one: rows in must
equal rows out plus every exclusion, and the check is an error rather
than a note.

A rule that evaluates to `NA` for a row is not a pass. A row whose
eligibility cannot be determined is excluded under its own heading,
because treating unknown as eligible and treating it as ineligible are
different studies and the difference belongs in the diagram.

Nothing here imputes, recodes or drops a column. Missingness is
described by
[`cp_eda()`](https://mufflyt.github.io/mysterymodel/reference/cp_eda.md)
and handled at imputation, where the choice is explicit.

## Examples

``` r
raw <- cp_synthetic_cohort(n = 300, seed = 1)
clean <- cp_clean(raw, rules = list(
  "aged 40 or over" = ~ age >= 40,
  "plausible BMI"   = ~ bmi >= 16 & bmi <= 55
))
clean
#> <cp_cohort>  300 in, 284 out, 16 excluded
#>      300  rows as supplied
#>      -10  aged 40 or over (did not meet the criterion)
#>      290  remaining
#>       -6  plausible BMI (did not meet the criterion)
#>      284  remaining
clean$ledger
#>   step             rule n_before n_excluded n_after                     reason
#> 1    0 rows as supplied       NA         NA     300            starting cohort
#> 2    1  aged 40 or over      300         10     290 did not meet the criterion
#> 3    2    plausible BMI      290          6     284 did not meet the criterion
```
