# Split a cohort the way the project declares

One place, so that fitting, validation and held-out scoring cannot
disagree about which rows are development.

## Usage

``` r
mm_split(project, cohort)
```

## Arguments

- project:

  A
  [`mm_project()`](https://mufflyt.github.io/mysterymodel/reference/mm_project.md).

- cohort:

  The cohort.

## Value

A list with `dev` and `held`.
