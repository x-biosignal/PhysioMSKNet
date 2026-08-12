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
