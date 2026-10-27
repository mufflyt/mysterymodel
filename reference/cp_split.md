# Split a cohort the way the project declares

One place, so that fitting, validation and held-out scoring cannot
disagree about which rows are development.

## Usage

``` r
cp_split(project, cohort)
```

## Arguments

- project:

  A
  [`cp_project()`](https://mufflyt.github.io/mysterymodel/reference/cp_project.md).

- cohort:

  The cohort.

## Value

A list with `dev` and `held`.
