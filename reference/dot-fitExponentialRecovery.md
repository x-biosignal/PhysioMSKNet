# Fit exponential recovery curve with NLS fallback to linear

Model: y = a \* (1 - exp(-b \* t)) + c

## Usage

``` r
.fitExponentialRecovery(t, y)
```

## Arguments

- t:

  Numeric vector of time indices.

- y:

  Numeric vector of observed values.

## Value

A list with: coefficients, residuals, r_squared, aic, model_type,
predicted, converged.
