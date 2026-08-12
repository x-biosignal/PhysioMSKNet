# Fit linear recovery model

Model: y = a + b \* t

## Usage

``` r
.fitLinearRecovery(t, y)
```

## Arguments

- t:

  Numeric vector of time indices.

- y:

  Numeric vector of observed values.

## Value

A list with: coefficients, residuals, r_squared, aic, model_type,
predicted, converged.
