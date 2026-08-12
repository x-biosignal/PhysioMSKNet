# Auto-select number of synergies by VAF criterion

Auto-select number of synergies by VAF criterion

## Usage

``` r
.selectNSynergies(V, max_k = 10L, threshold = 0.9, seed = NULL)
```

## Arguments

- V:

  Non-negative matrix (n_muscles x n_time).

- max_k:

  Maximum k to try.

- threshold:

  VAF threshold (default: 0.90).

- seed:

  Random seed.

## Value

A list with: optimal_k, vaf_curve.
