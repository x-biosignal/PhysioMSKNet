# MSK Network Metrics

Computes standard graph metrics for the projected bone or muscle graph.

## Usage

``` r
mskNetworkMetrics(hg, type = c("bone", "muscle"))
```

## Arguments

- hg:

  An MSKHypergraph object.

- type:

  Character, "bone" or "muscle" projection.

## Value

A list with: degree, strength, clustering_coef, density
