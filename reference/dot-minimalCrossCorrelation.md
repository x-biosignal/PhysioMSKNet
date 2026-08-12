# Minimal cross-correlation for electromechanical delay

Fallback cross-correlation when PhysioCrossModal is unavailable.

## Usage

``` r
.minimalCrossCorrelation(x, y, max_lag)
```

## Arguments

- x:

  Numeric vector (signal 1).

- y:

  Numeric vector (signal 2, same length as x).

- max_lag:

  Integer, maximum lag to compute.

## Value

A list with: peak_lag, peak_correlation, correlation (vector), lags
(integer vector).
