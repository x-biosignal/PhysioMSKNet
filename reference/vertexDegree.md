# Vertex (Bone) Degree

Returns the degree of each vertex (bone), i.e., the number of muscles
attached to each bone.

## Usage

``` r
vertexDegree(hg)
```

## Arguments

- hg:

  An MSKHypergraph object or incidence matrix.

## Value

Named numeric vector of bone degrees.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
vertexDegree(MSKHypergraph(C))
#> b1 b2 b3 b4 
#>  2  2  2  2 
```
