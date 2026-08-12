# Predict composite function score (LEFS-like, 0-80)

Aggregates ROM and strength weighted by muscle degree (structural
importance).

## Usage

``` r
.predictFunctionScore(rom, strength, muscle_weights = NULL)
```

## Arguments

- rom:

  Numeric vector of ROM percentages.

- strength:

  Numeric vector of strength percentages.

- muscle_weights:

  Numeric vector of weights (e.g., normalized degree).

## Value

Numeric scalar function score (0-80).
