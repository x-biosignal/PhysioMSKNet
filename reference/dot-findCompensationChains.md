# Find compensation chains via DFS

Finds paths through compensating muscles in the compensation adjacency
matrix using depth-first search.

## Usage

``` r
.findCompensationChains(adj_matrix, max_length = 5L)
```

## Arguments

- adj_matrix:

  Numeric matrix (square, weighted adjacency).

- max_length:

  Integer, maximum chain length (default: 5).

## Value

A list of character vectors, each representing a compensation chain.
