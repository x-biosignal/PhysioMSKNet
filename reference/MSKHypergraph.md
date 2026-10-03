# Create MSK Hypergraph Object

Constructs a musculoskeletal hypergraph from an incidence matrix. In
this hypergraph, bones are vertices and muscles are hyperedges. A muscle
(hyperedge) connects all bones it attaches to.

## Usage

``` r
MSKHypergraph(C = NULL, muscle_meta = NULL)
```

## Arguments

- C:

  A matrix or sparse Matrix (bones x muscles) where C\[i,j\]=1 means
  muscle j attaches to bone i. If NULL, loads the built-in data.

- muscle_meta:

  Optional data.frame with muscle metadata.

## Value

An S3 object of class "MSKHypergraph" containing:

- C:

  Sparse incidence matrix (bones x muscles)

- n_bones:

  Number of bones (vertices)

- n_muscles:

  Number of muscles (hyperedges)

- bone_names:

  Character vector of bone names

- muscle_names:

  Character vector of muscle names

- muscle_meta:

  Muscle metadata if provided

## References

Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.

## Examples

``` r
## Tiny synthetic incidence matrix: 4 bones x 4 muscles (a ring)
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
hg <- MSKHypergraph(C)
hg
#> MSKHypergraph
#>   Bones (vertices): 4 
#>   Muscles (hyperedges): 4 
#>   Connections: 8 
#>   Sparsity: 0.5 
#>   Muscle degree range: 2-2 
#>   Bone degree range: 2-2 

## Or load the bundled Murphy et al. (2018) dataset
hg_full <- MSKHypergraph()
hg_full$n_bones
#> [1] 173
```
