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
