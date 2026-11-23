# What the band means, for the person it is about

A different piece of writing, not the same one with simpler words.
Someone reading their own number is not weighing a decision about a
third party; they are being told something about themselves by a
machine, and the three things they need are what the number counts, what
it cannot see, and what to do next.

## Usage

``` r
mm_band_text_self(
  prob,
  threshold,
  level,
  subject,
  event = "the outcome",
  n_predictors = NULL
)
```

## Arguments

- prob, threshold:

  Probabilities.

- level:

  The band.

- subject:

  What one row is, in the singular.

- event:

  What the outcome is, in the past tense, as it would complete "of 100
  ..., 15 \_\_\_".

- n_predictors:

  How many predictors the model holds, or `NULL`.

## Value

A single string.

## Details

So: no odds ratio, because a ratio of odds is not a fact anyone can hold
about themselves. A count out of a hundred instead, for both the
prediction and the reference, because "15 in 100" is the form of this
quantity people read most reliably. The number of predictors is named,
because the strongest honest thing to say about a low prediction is how
little of an application the model actually saw. The low bands neither
reassure nor commiserate: the number is reported, what the model could
not see is named, and the reader is sent to someone who can advise them.
