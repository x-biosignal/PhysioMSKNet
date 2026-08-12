# Generate Null Hypergraph

Creates a randomized version of the musculoskeletal hypergraph by
rewiring muscle-bone connections while preserving each muscle's degree
(number of bones it connects to). This is done by randomly reassigning
which bones each muscle attaches to, within anatomical categories if
specified.

## Usage

``` r
mskNullHypergraph(hg = NULL, preserve_category = FALSE)
```

## Arguments

- hg:

  An MSKHypergraph object. If NULL, loads built-in data.

- preserve_category:

  Logical, whether to preserve anatomical category during rewiring
  (default: FALSE for the basic model).

## Value

An MSKHypergraph object with rewired connections.

## References

Murphy AC et al. (2018) PLOS Biology.
