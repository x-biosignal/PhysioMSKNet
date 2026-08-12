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
