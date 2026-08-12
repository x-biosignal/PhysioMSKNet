# Permutation-based Mantel test for matrix correlation

Computes Pearson correlation between upper triangles of two symmetric
matrices and tests significance via permutation.

## Usage

``` r
.mantelTest(mat1, mat2, n_perm = 999L)
```

## Arguments

- mat1:

  Numeric matrix (symmetric).

- mat2:

  Numeric matrix (symmetric, same dimension as mat1).

- n_perm:

  Integer, number of permutations (default: 999).

## Value

A list with: correlation, p_value, n_perm.
