# External benchmark registry

Every cohort this package has been validated against that it does not ship
itself, with the provenance needed to re-run the comparison and to notice if
the data underneath it changes.

None of it is vendored into the package. Two separate reasons, recorded
because they are different:

* **UCLA admissions** carries no stated licence. It is teaching material, and
  redistributing it under this package's MIT licence would be a claim about
  rights that cannot be checked from here.
* **IBM Telco** is Apache-2.0 and may be redistributed with attribution, so
  the objection above does not apply. It is still not vendored: at 948 KB it
  would be the largest thing in a repository whose source is about 640 KB in
  total, and a telecoms churn dataset is not clinical-prediction package data.

What runs on every build instead are the invariances, which are properties of
a parameterisation rather than of anyone's rows, on synthetic cohorts. See
`inst/decisions.md`, DEC-011, for why that split is the right one rather than
merely the convenient one. The comparisons that genuinely need these cohorts
are one-off confirmations, re-runnable from `data-raw/external_benchmark.R`.

## Fetched over the network

| dataset | source | licence | rows x cols | outcome | SHA-256 |
|---|---|---|---|---|---|
| UCLA graduate admissions | `https://stats.oarc.ucla.edu/stat/data/binary.csv` | none stated | 400 x 4 | `admit`, 0/1, 127 events | `41e2312ca09d50e99c2db67fbabc78d215df6ce71eefe880df5e9310a9fa8397` |
| IBM Telco customer churn | `https://raw.githubusercontent.com/IBM/telco-customer-churn-on-icp4d/master/data/Telco-Customer-Churn.csv` | Apache-2.0 | 7043 x 21 | `Churn`, No/Yes, 1869 events | `16320c9c1ec72448db59aa0a26a0b95401046bef5d02fd3aeb906448e3055e91` |
| Titanic, Harrell's `titanic3` | `Hmisc::getHdata(titanic3)`, hbiostat.org | see hbiostat.org | 1309 x 14 | `survived`, 0/1, 500 events | fetched by `getHdata`, not checksummed here |

The published reference values for UCLA are in DEC-011. The Telco URL that
looks like a repository path, `github.com/IBM/...`, returns an HTML error
page; the `raw.githubusercontent.com` form above is the one that serves the
file, and the `main` branch does not exist for that repository.

## From installed packages

| dataset | package | rows | outcome | what it tests |
|---|---|---|---|---|
| `birthwt` | MASS | 189 | `low`, 59 events | the canonical Venables and Ripley example |
| `aSAH` | pROC | 113 | `outcome`, 41 Poor | pROC's own ROC example, so the DeLong interval |
| `bacteria` | MASS | 220, 50 subjects | `y`, 177 events | real repeated measures, so clustered resampling |
| `Pima.tr` / `Pima.te` | MASS | 200 / 332 | `type` | a genuine train/test split |
| `esoph` | datasets | 88 grouped, 975 expanded | `cbind(ncases, ncontrols)` | grouped binomial, and ordered factors |
| `SynthDiabetes` / `SynthDiabetes2` | mlbench | 768 | `diabetes`, 280 pos | impossible zeros kept against recoded as missing |
| `Default` | ISLR2 | 10000 | `default`, No/Yes, 333 events | the event level of a factor outcome |
| `Weekly` | ISLR2 | 1089 | `Direction`, Down/Up | factor coding, and a year-based split |
| `?validate.lrm` | rms | 1000 simulated | `y`, simulated | the author's own spline-by-factor example |

Versions these were verified against:

```
MASS     7.3.65
pROC     1.18.5
mlbench  2.1.11
ISLR2    1.3.2
rms      8.1.1
Hmisc    5.3.0
```

## What each benchmark found

The defects are recorded in `inst/decisions.md`. In short: `titanic3` found
`mm_interactions()` testing each block against a baseline that already
contained it; Pima found the same defect in `mm_splines()`; UCLA found ordered
factors refused unconditionally; `Default` found the event level inferred from
sort order; Telco found an identifier accepted as a predictor and a
main-effects model whose failure was reported as a failure of a block.

Agreement, where the engine owns the number, has been exact throughout:
coefficients, fitted probabilities and deviance to zero against `rms` given
the same formula, and to optimiser tolerance against `stats::glm()`.
