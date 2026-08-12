# Fit sigmoid recovery curve with NLS fallback to linear

Model: y = L / (1 + exp(-k \* (t - t0)))

## Usage

``` r
.fitSigmoidRecovery(t, y)
```

## Arguments

- t:

  Numeric vector of time indices.

- y:

  Numeric vector of observed values.

## Value

A list with: coefficients, residuals, r_squared, aic, model_type,
predicted, converged.
