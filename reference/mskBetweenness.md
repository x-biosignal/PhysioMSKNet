# Betweenness Centrality via BFS

Computes betweenness centrality for the projected graph. Uses igraph if
available, otherwise a pure-R BFS implementation.

## Usage

``` r
mskBetweenness(hg, type = c("bone", "muscle"))
```

## Arguments

- hg:

  An MSKHypergraph object.

- type:

  Character, "bone" or "muscle" projection.

## Value

Named numeric vector of betweenness centrality values.
