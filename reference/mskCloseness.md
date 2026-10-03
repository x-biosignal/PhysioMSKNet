# Closeness Centrality

Closeness Centrality

## Usage

``` r
mskCloseness(hg, type = c("bone", "muscle"))
```

## Arguments

- hg:

  An MSKHypergraph object.

- type:

  Character, "bone" or "muscle" projection.

## Value

Named numeric vector of closeness centrality values.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
mskCloseness(MSKHypergraph(C), type = "bone")
#>   b1   b2   b3   b4 
#> 0.25 0.25 0.25 0.25 
```
