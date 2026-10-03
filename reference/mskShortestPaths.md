# Shortest Path Distances

Computes shortest path distance matrix for the projected graph.

## Usage

``` r
mskShortestPaths(hg, type = c("bone", "muscle"))
```

## Arguments

- hg:

  An MSKHypergraph object.

- type:

  Character, "bone" or "muscle" projection.

## Value

A numeric matrix of shortest path distances.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
mskShortestPaths(MSKHypergraph(C), type = "bone")
#>    b1 b2 b3 b4
#> b1  0  1  2  1
#> b2  1  0  1  2
#> b3  2  1  0  1
#> b4  1  2  1  0
```
