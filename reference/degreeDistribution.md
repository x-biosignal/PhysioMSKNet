# Degree Distribution

Computes the degree distribution for bones or muscles.

## Usage

``` r
degreeDistribution(hg, type = c("muscle", "bone"))
```

## Arguments

- hg:

  An MSKHypergraph object.

- type:

  Character, either "muscle" (hyperedge degree) or "bone" (vertex
  degree).

## Value

A data.frame with columns: degree, count, probability
