# Is the development sample adequate for the parameters spent

Reports what the specification asks a prediction model to disclose about
its own size: rows, events, prevalence, the number of candidate
parameters including spline and interaction terms, the expected
shrinkage, and the development sample a model of this shape would need.

## Usage

``` r
cp_adequacy(
  n,
  events,
  parameters,
  nagelkerke,
  likelihood_ratio = NA_real_,
  shrinkage = 0.9
)
```

## Arguments

- n:

  Development rows.

- events:

  Outcome events among them.

- parameters:

  Non-intercept model parameters.

- nagelkerke:

  Nagelkerke R-squared from the fitted model.

- likelihood_ratio:

  Model likelihood ratio chi-squared.

- shrinkage:

  Target shrinkage for the requirement, conventionally 0.9.

## Value

An object of class `cp_adequacy`.

## Details

The gate is the Riley requirement from
[`pmsampsize::pmsampsize()`](https://rdrr.io/pkg/pmsampsize/man/pmsampsize.html),
not the events-per-parameter rule. Events per parameter is reported
because readers expect it, and labelled as description rather than as
the criterion, which is what the specification asks for.

One circularity is disclosed rather than hidden. The required sample
size depends on the model's explanatory performance, which before
fitting is a guess and after fitting is an estimate from the very data
whose adequacy is in question. The figure here uses the fitted
Nagelkerke R-squared, so it answers "was this sample adequate for the
model it produced", not "how large a sample should have been collected".
The second question needs an R-squared from outside these data.
