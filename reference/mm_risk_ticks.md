# Risk ticks that are evenly spaced on the drawn axis

Chosen in the linear predictor, where the sheet is linear, and converted
to probabilities. Rounded to figures a reader would write down, which
moves each tick slightly off its even spacing; that is the right trade,
because a tick labelled 0.37 is not more useful than one labelled 0.35
and the point of the exercise is a label somebody can read.

## Usage

``` r
mm_risk_ticks(lp_real, n = 7L)
```

## Arguments

- lp_real:

  The linear-predictor values the lp axis carries.

- n:

  How many ticks to aim for.

## Value

A sorted vector of probabilities, possibly shorter than `n` after
rounding collapses neighbours.
