# Project to Muscle-centric Graph

Creates the muscle-muscle weighted adjacency matrix B = C %\*% t(C)
where B\[i,j\] counts the number of bones shared between muscles i and
j. This is the one-mode projection onto the muscle (hyperedge) space.

## Usage

``` r
projectMuscleGraph(hg)
```

## Arguments

- hg:

  An MSKHypergraph object, or a sparse incidence matrix.

## Value

A symmetric sparse Matrix (n_muscles x n_muscles)

## References

Murphy AC et al. (2018) PLOS Biology.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
hg <- MSKHypergraph(C)
as.matrix(projectMuscleGraph(hg))
#>    m1 m2 m3 m4
#> m1  0  1  0  1
#> m2  1  0  1  0
#> m3  0  1  0  1
#> m4  1  0  1  0
```
