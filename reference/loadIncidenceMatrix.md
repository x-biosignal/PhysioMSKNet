# Load Incidence Matrix

Loads the bipartite incidence matrix C where rows are bones (vertices)
and columns are muscles (hyperedges). Entry C\[i,j\] = 1 indicates that
muscle j attaches to bone i.

## Usage

``` r
loadIncidenceMatrix()
```

## Value

A sparse Matrix (dgCMatrix) of dimensions 173 x 270

## References

Murphy AC et al. (2018) PLOS Biology.
