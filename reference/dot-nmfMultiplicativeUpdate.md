# NMF via multiplicative update rules (Lee & Seung 2001)

NMF via multiplicative update rules (Lee & Seung 2001)

## Usage

``` r
.nmfMultiplicativeUpdate(V, k, max_iter = 500L, tol = 1e-06, seed = NULL)
```

## Arguments

- V:

  Non-negative matrix (n_muscles x n_time).

- k:

  Number of synergies.

- max_iter:

  Maximum iterations.

- tol:

  Convergence tolerance.

- seed:

  Random seed for reproducibility.

## Value

A list with: W, H, reconstruction_error, n_iter, converged.
