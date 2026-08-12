# Pairwise Granger causality test

Tests if past of x improves prediction of y. Selects optimal model order
via AIC or BIC.

## Usage

``` r
.grangerCausalityPairwise(x, y, max_order = 10L, criterion = c("aic", "bic"))
```

## Arguments

- x:

  Numeric vector (predictor signal).

- y:

  Numeric vector (response signal).

- max_order:

  Integer, maximum lag order to test.

- criterion:

  Character, "aic" or "bic" for model order selection.

## Value

A list with: f_statistic, p_value, optimal_order, direction.
