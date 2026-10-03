# Project to Bone-centric Graph

Creates the bone-bone weighted adjacency matrix A = t(C) %\*% C where
A\[i,j\] counts the number of muscles shared between bones i and j. This
is the one-mode projection onto the bone (vertex) space.

## Usage

``` r
projectBoneGraph(hg)
```

## Arguments

- hg:

  An MSKHypergraph object, or a sparse incidence matrix.

## Value

A symmetric sparse Matrix (n_bones x n_bones)

## References

Murphy AC et al. (2018) PLOS Biology.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
hg <- MSKHypergraph(C)
as.matrix(projectBoneGraph(hg))
#>    b1 b2 b3 b4
#> b1  0  1  0  1
#> b2  1  0  1  0
#> b3  0  1  0  1
#> b4  1  0  1  0
```
