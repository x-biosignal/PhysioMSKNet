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

## Examples

``` r
hg <- MSKHypergraph()
head(degreeDistribution(hg, type = "muscle"))
#>   degree count probability
#> 1      1     2 0.007407407
#> 2      2   146 0.540740741
#> 3      3    47 0.174074074
#> 4      4    24 0.088888889
#> 5      5    10 0.037037037
#> 6      6     7 0.025925926
```
