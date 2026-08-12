# Identify MSK neighbors within N hops

Finds all muscle indices reachable from a set of source muscles within a
specified number of hops in the MSK muscle graph.

## Usage

``` r
.identifyMSKNeighbors(muscle_indices, hg, order = 2L)
```

## Arguments

- muscle_indices:

  Integer vector of source muscle indices.

- hg:

  An MSKHypergraph object.

- order:

  Integer, maximum number of hops (default: 2).

## Value

A list with: indices (integer vector of neighbor indices, excluding
sources), distances (named numeric vector of shortest distances from any
source to each neighbor).
