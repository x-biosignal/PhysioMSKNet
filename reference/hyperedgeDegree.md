# Hyperedge (Muscle) Degree

Returns the degree of each hyperedge (muscle), i.e., the number of bones
each muscle attaches to.

## Usage

``` r
hyperedgeDegree(hg)
```

## Arguments

- hg:

  An MSKHypergraph object or incidence matrix.

## Value

Named numeric vector of muscle degrees.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
hyperedgeDegree(MSKHypergraph(C))
#> m1 m2 m3 m4 
#>  2  2  2  2 
```
