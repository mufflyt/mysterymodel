# One numeric input, switched on or off

A disabled `fieldset` rather than a removed control or a line of
JavaScript. The browser greys an input inside one and refuses to let it
be typed in, and Shiny still reports its value, so the form submits the
parked figure and the row stays complete. Removing the control instead
would leave the predictor missing and the model unable to score the row
at all, which is the opposite of the point.

## Usage

``` r
mm_calculator_gated_input(predictor, id, spec, value, shut, gate)
```

## Arguments

- predictor:

  The predictor's name.

- id:

  Its input identifier.

- spec:

  Its entry in the prediction schema.

- value:

  What the box reads.

- shut:

  Whether the gate is closed.

- gate:

  The gate, for the sentence explaining why.

## Value

A Shiny tag.
