# Generate Null Hypergraph Ensemble

Creates multiple null hypergraphs and computes impact scores for each.
This is used to compute impact deviations relative to the null
distribution.

## Usage

``` r
mskNullEnsemble(hg = NULL, n_null = 100L, sim_params = list(), verbose = TRUE)
```

## Arguments

- hg:

  An MSKHypergraph object.

- n_null:

  Number of null models to generate (default: 100).

- sim_params:

  List of simulation parameters (dt, n_steps, beta).

- verbose:

  Logical, print progress.

## Value

A list with:

- null_scores:

  Matrix of impact scores (n_muscles x n_null)

- null_degree_scores:

  List, impact scores grouped by degree for each null

- n_null:

  Number of null models

## References

Murphy AC et al. (2018) PLOS Biology.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
set.seed(1)
ens <- mskNullEnsemble(MSKHypergraph(C), n_null = 3,
                       sim_params = list(n_steps = 50), verbose = FALSE)
dim(ens$null_scores)
#> [1] 4 3
```
