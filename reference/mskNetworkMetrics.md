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

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
m <- mskNetworkMetrics(MSKHypergraph(C), type = "bone")
m$density
#> [1] 0.6666667
m$degree
#> b1 b2 b3 b4 
#>  2  2  2  2 
```
