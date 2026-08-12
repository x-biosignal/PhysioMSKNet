# Compute Modularity

Computes the modularity Q of a partition with resolution parameter. Q =
(1/2m) \* sum_ij (A_ij - gamma \* k_i \* k_j / (2m)) \* delta(c_i, c_j)

## Usage

``` r
mskModularity(A, membership, gamma = 1)
```

## Arguments

- A:

  Adjacency matrix.

- membership:

  Integer vector of community assignments.

- gamma:

  Resolution parameter (default: 1.0).

## Value

Numeric modularity value.
