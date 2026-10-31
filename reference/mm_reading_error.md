# The most an off-tick reading can differ from the model

A bound, not a probe. The quantity is attained by some profile a
clinician could read, so it answers "how wrong can this nomogram be
between its printed ticks" rather than "how wrong was it at the places I
happened to look".

## Usage

``` r
mm_reading_error(nom, model, per_gap = 5L)
```

## Arguments

- nom:

  An `rms` nomogram.

- model:

  A
  [`mm_model()`](https://mufflyt.github.io/mysterymodel/reference/mm_model.md).

- per_gap:

  Interior points scanned in each gap between ticks. Cost is linear in
  it and in the number of axes, and the answer is stable well below the
  default.

## Value

A list: `bound`, the largest absolute risk difference any reading
between ticks can carry; `lp`, the same bound on the linear-predictor
scale; and `by_axis`, each axis's own error range, which is where to
look when the bound is too large and the question is which axis needs
more ticks. `bound` and `lp` are `NA` when no axis has two ticks to read
between, because then there is no off-tick reading to make.

## Why a bound is computable without searching the joint space

Total points are additive across axes and the printed linear-predictor
axis is affine in them, so for any profile

\$\$lp\_{nomogram} - lp\_{model} = b \sum_j e_j(x_j)\$\$

where \\e_j\\ is one axis's linear-interpolation error in points and
\\b\\ is the points-to-lp slope. Each \\e_j\\ is zero at that axis's own
ticks, which is what the tick-agreement check in
[`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
establishes, and each is free to take its own worst value because the
predictors are chosen independently. So the extremes of the sum are the
sums of the extremes, and one scan per axis is enough: no search over
combinations of predictors is needed, and none is done.

Each axis is scanned with every other predictor sitting on a tick, so
the discrepancy observed is exactly that axis's. An axis is scanned once
per stratum it is drawn in, because an interaction with a factor gives a
continuous predictor a different points curve per level and `rms` draws
those as separate axes: on one fixture the `age` error ran to -0.046 in
one stratum where the other reached only -0.006, so a single stratum is
not a bound over both.

The worst total error in points becomes a worst error in risk through
the logistic, whose steepest point is the one that matters: \\\max_u
\|plogis(u + \delta) - plogis(u)\|\\ is attained at \\u = -\delta/2\\,
that is at a risk of one half. The bound does not ask whether a profile
with that risk also attains the worst points error, so it holds whether
or not one does.

## What it does not cover

Interpolation only. Not the clinician's eye on the printed page, not a
total falling off the drawn scale, which
[`mm_nomogram()`](https://mufflyt.github.io/mysterymodel/reference/mm_nomogram.md)
counts separately as `off_axis`, and not a predictor outside the range
the model was developed on, which
[`mm_predict()`](https://mufflyt.github.io/mysterymodel/reference/mm_predict.md)
marks as `.extrapolated`. It is also a numerical bound rather than an
analytic one: each axis is scanned on a finite grid, so a sharper
extremum could sit between two scanned points. Measured, that slack is
about one part in a thousand: raising `per_gap` from 3 to 25 moved the
lp bound from 0.12613 to 0.12626 on a two-spline fixture whose worst
observed reading was 0.0215 against a bound of 0.0315. The slack runs an
order of magnitude smaller than the margin the bound already carries.
