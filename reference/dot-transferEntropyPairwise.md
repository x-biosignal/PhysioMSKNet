# Pairwise transfer entropy

Discretization-based transfer entropy from x to y.

## Usage

``` r
.transferEntropyPairwise(x, y, lag = 1L, n_bins = NULL)
```

## Arguments

- x:

  Numeric vector (source signal).

- y:

  Numeric vector (target signal).

- lag:

  Integer, time lag.

- n_bins:

  Integer, number of bins for discretization (NULL for auto).

## Value

A list with: te_value, n_bins_used, effective_n.
